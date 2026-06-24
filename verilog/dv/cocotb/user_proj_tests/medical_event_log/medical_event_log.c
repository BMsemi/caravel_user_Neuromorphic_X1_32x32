#define USER_ADDR_SPACE_C_HEADER_FILE

#include <firmware_apis.h>
#include <custom_user_space.h>
#include <stdint.h>

#define X1_MAILBOX_ADDR 0x30000004u
#define X1_MODE_RESET   0u
#define X1_MODE_READ    1u
#define X1_MODE_SET     3u

#define X1_CONFIG_SET_TARGETS   0xA203C40Fu
#define X1_CONFIG_RESET_TARGETS 0x0F030D43u
#define X1_CONFIG_TIMING        0x42000C03u

#define EVENT_BOOT              0x01u
#define EVENT_SENSOR_FAULT      0x20u
#define EVENT_THERAPY_DELIVERED 0x30u
#define EVENT_BATTERY_LOW       0x40u

#define SEVERITY_INFO     0u
#define SEVERITY_WARNING  1u
#define SEVERITY_CRITICAL 2u

#define COMMIT_NONE 0u
#define COMMIT_A    1u
#define COMMIT_BOTH 2u

#define COMMIT_A_BIT 30u
#define COMMIT_B_BIT 31u
#define PAYLOAD_MASK 0x3FFFFFFFu
#define COMMIT_MASK  0xC0000000u

static volatile uint32_t *const x1_mailbox =
    (volatile uint32_t *)X1_MAILBOX_ADDR;

static uint32_t x1_pack_command(uint32_t mode, uint32_t row,
                                uint32_t column, uint32_t data)
{
    return ((mode & 0x3u) << 30) |
           ((row & 0x1Fu) << 25) |
           ((column & 0x1Fu) << 20) |
           (data & 0xFFu);
}

static void x1_write_word(uint32_t word)
{
    *x1_mailbox = word;
}

static void x1_configure(void)
{
    /* The behavioral X1 model consumes the first three mailbox writes as
     * configuration packets. Keep these values aligned with its reset defaults.
     */
    x1_write_word(X1_CONFIG_SET_TARGETS);
    x1_write_word(X1_CONFIG_RESET_TARGETS);
    x1_write_word(X1_CONFIG_TIMING);
}

static void x1_reset_cell(uint32_t row, uint32_t column)
{
    x1_write_word(x1_pack_command(X1_MODE_RESET, row, column, 0u));
}

static void x1_set_cell(uint32_t row, uint32_t column)
{
    x1_write_word(x1_pack_command(X1_MODE_SET, row, column, 0xFFu));
}

static uint32_t x1_read_cell(uint32_t row, uint32_t column)
{
    x1_write_word(x1_pack_command(X1_MODE_READ, row, column, 0u));
    return *x1_mailbox & 0x1u;
}

static uint8_t crc8_update(uint8_t crc, uint8_t data)
{
    uint32_t bit;

    for (bit = 0u; bit < 8u; ++bit) {
        uint8_t feedback = (uint8_t)((crc ^ data) & 0x80u);
        crc = (uint8_t)(crc << 1);
        if (feedback != 0u) {
            crc ^= 0x07u;
        }
        data = (uint8_t)(data << 1);
    }

    return crc;
}

static uint8_t record_crc(uint8_t event_code, uint8_t sequence,
                          uint8_t source, uint8_t severity)
{
    uint8_t crc = 0u;

    crc = crc8_update(crc, event_code);
    crc = crc8_update(crc, sequence);
    crc = crc8_update(crc,
                      (uint8_t)(((source & 0x0Fu) << 4) |
                                (severity & 0x03u)));
    return crc;
}

static uint32_t record_payload(uint8_t event_code, uint8_t sequence,
                               uint8_t source, uint8_t severity)
{
    uint32_t crc = record_crc(event_code, sequence, source, severity);

    return ((uint32_t)event_code) |
           ((uint32_t)sequence << 8) |
           ((uint32_t)(source & 0x0Fu) << 16) |
           ((uint32_t)(severity & 0x03u) << 20) |
           (crc << 22);
}

static void x1_clear_record(uint32_t row)
{
    uint32_t column;

    /* Invalidate the old row before touching payload bits. If power is lost
     * during the remaining erase, replay sees missing commit bits and rejects
     * the row instead of accepting a partially modified old record.
     */
    x1_reset_cell(row, COMMIT_B_BIT);
    x1_reset_cell(row, COMMIT_A_BIT);

    for (column = 0u; column < COMMIT_A_BIT; ++column) {
        x1_reset_cell(row, column);
    }
}

static void x1_program_record(uint32_t row, uint8_t event_code,
                              uint8_t sequence, uint8_t source,
                              uint8_t severity, uint32_t commit_state)
{
    uint32_t column;
    uint32_t payload = record_payload(event_code, sequence, source, severity);

    x1_clear_record(row);

    /* Payload and CRC are written before either commit bit. A torn update is
     * therefore ignored during replay unless both commit bits are present.
     */
    for (column = 0u; column < COMMIT_A_BIT; ++column) {
        if ((payload & (1u << column)) != 0u) {
            x1_set_cell(row, column);
        }
    }

    if (commit_state >= COMMIT_A) {
        x1_set_cell(row, COMMIT_A_BIT);
    }
    if (commit_state >= COMMIT_BOTH) {
        x1_set_cell(row, COMMIT_B_BIT);
    }
}

static uint32_t x1_read_record(uint32_t row)
{
    uint32_t column;
    uint32_t raw = 0u;

    for (column = 0u; column < 32u; ++column) {
        raw |= x1_read_cell(row, column) << column;
    }

    return raw;
}

static uint32_t record_is_valid(uint32_t raw)
{
    uint8_t event_code;
    uint8_t sequence;
    uint8_t source;
    uint8_t severity;
    uint8_t stored_crc;

    if ((raw & COMMIT_MASK) != COMMIT_MASK) {
        return 0u;
    }

    event_code = (uint8_t)(raw & 0xFFu);
    sequence = (uint8_t)((raw >> 8) & 0xFFu);
    source = (uint8_t)((raw >> 16) & 0x0Fu);
    severity = (uint8_t)((raw >> 20) & 0x03u);
    stored_crc = (uint8_t)((raw >> 22) & 0xFFu);

    return stored_crc == record_crc(event_code, sequence, source, severity);
}

static uint32_t record_fields_match(uint32_t raw, uint8_t event_code,
                                    uint8_t sequence, uint8_t source,
                                    uint8_t severity)
{
    return ((raw & PAYLOAD_MASK) ==
            record_payload(event_code, sequence, source, severity));
}

void main(void)
{
    uint32_t row0;
    uint32_t row1;
    uint32_t row2;
    uint32_t row3;
    uint32_t failed = 0u;

    ManagmentGpio_outputEnable();
    ManagmentGpio_write(0);
    GPIOs_configureAll(GPIO_MODE_USER_STD_INPUT_NOPULL);
    GPIOs_loadConfigs();
    User_enableIF(1);

    /* Signal cocotb that firmware initialization is complete. */
    ManagmentGpio_write(1);

    x1_configure();

    /* Valid boot event. */
    x1_program_record(0u, EVENT_BOOT, 1u, 0u,
                      SEVERITY_INFO, COMMIT_BOTH);

    /* First commit an old record, then simulate an interrupted slot reuse.
     * The clear path invalidates commit-B before changing the payload.
     */
    x1_program_record(1u, EVENT_BOOT, 0u, 1u,
                      SEVERITY_INFO, COMMIT_BOTH);
    x1_program_record(1u, EVENT_BATTERY_LOW, 2u, 1u,
                      SEVERITY_WARNING, COMMIT_A);

    /* Valid therapy event. */
    x1_program_record(2u, EVENT_THERAPY_DELIVERED, 3u, 2u,
                      SEVERITY_INFO, COMMIT_BOTH);

    /* Valid record followed by a one-bit corruption. CRC must reject it. */
    x1_program_record(3u, EVENT_SENSOR_FAULT, 4u, 3u,
                      SEVERITY_CRITICAL, COMMIT_BOTH);
    x1_set_cell(3u, 0u);

    row0 = x1_read_record(0u);
    row1 = x1_read_record(1u);
    row2 = x1_read_record(2u);
    row3 = x1_read_record(3u);

    if (record_is_valid(row0) == 0u ||
        record_fields_match(row0, EVENT_BOOT, 1u, 0u,
                            SEVERITY_INFO) == 0u) {
        failed |= 1u << 0;
    }

    if (record_is_valid(row1) != 0u ||
        (row1 & COMMIT_MASK) != (1u << COMMIT_A_BIT)) {
        failed |= 1u << 1;
    }

    if (record_is_valid(row2) == 0u ||
        record_fields_match(row2, EVENT_THERAPY_DELIVERED, 3u, 2u,
                            SEVERITY_INFO) == 0u) {
        failed |= 1u << 2;
    }

    if (record_is_valid(row3) != 0u ||
        (row3 & COMMIT_MASK) != COMMIT_MASK) {
        failed |= 1u << 3;
    }

    if (failed == 0u) {
        /* A falling edge is the PASS indication consumed by cocotb. */
        ManagmentGpio_write(0);
    }

    /* Keep a failing run visible as mgmt_gpio=1 until the cocotb timeout. */
    while (1) {
        __asm__ volatile ("nop");
    }
}
