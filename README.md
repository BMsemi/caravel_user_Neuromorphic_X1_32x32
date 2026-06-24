
<table>
  <tr>
    <td align="center"><img src="bm-lab-logo-white.jpg" alt="BM LABS Logo" width="200"/></td>
    <td align="center"><img src="chip_foundry_logo.png" alt="Chipfoundry Logo" width="200"/></td>
  </tr>
</table>

# Caravel User Neuromorphic X1 Example

This project demonstrates the straightforward integration of a commercial Neuromorphic X1 within the `user_project_wrapper` using the IPM (IP Manager) tool.

## Medical-device event logging demo

The `medical_event_log` firmware+cocotb test uses the X1 mailbox at
`0x3000_0004` as a 32-slot event journal. Records include CRC-8 and two commit
bits so firmware can replay complete events while rejecting interrupted or
corrupted writes.

See [docs/medical_device_event_logger.md](docs/medical_device_event_logger.md)
for the record format, safety assumptions, test command, GL limitation, and
signoff checklist.

## Get Started Quickly

### Follow these steps to set up your environment and harden the Neuromorphic X1:

1. **Clone the Repository:**

```
git clone https://github.com/BMsemi/caravel_user_Neuromorphic_X1_32x32.git
```
2. **Prepare Your Environment:**

```
cd caravel_user_Neuromorphic_X1_32x32
make setup
```
3. **Install IPM:**

```
pip install cf-ipm
```
4. **Install the Neuromorphic X1 IP:**

```
Clone this Github Repo: https://github.com/BMsemi/Neuromorphic_X1_32x32
Copy the cloned folder Neuromorphic_X1_32x32 and paste it inside the ip folder
(OR)
ipm install Neuromorphic_X1_32x32  (if IP is updated in the CF ipm)
```

5. **Harden the User Project Wrapper using librelane/openlane2:**

```
make user_project_wrapper
```

6. **Harden the User Project Wrapper using librelane/openlane2: If wide Analog Routing is Required follow the steps below**

```
use **Widen_Analog_Routig_using_NDR.txt** file where instructions to widen the Analog Routing using NDR is given.
```

Details about the Neuromorphic X1 IP itself are available in the [Neuromorphic X1 documentation](https://github.com/BMsemi/Neuromorphic_X1_32x32)
