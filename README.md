# Syncthing for reMarkable

A [rm-appload](https://github.com/asivery/rm-appload) Syncthing application for reMarkable tablets. It will automatically install Syncthing and create a systemd service for you and allows you to monitor your syncing states. 

## Features

- 📊 **Real-time Monitoring** - View Syncthing service status and sync progress
- 🎛️ **Service Control** - Start, stop, and restart Syncthing service with a single tap
- 🚀 **Auto-Installer** - Automatically downloads and installs the latest Syncthing release

## Screenshots
<p align="center">
  <img src="https://github.com/user-attachments/assets/4e2262ab-be68-46a7-80d8-2d2a2a60940b" alt="installer" width="250"/>
  <img src="https://github.com/user-attachments/assets/91a2589b-7f66-4a47-bbff-5ac29e0c539d" alt="app" width="250"/>
  <img src="https://github.com/user-attachments/assets/848d74cf-8c02-429a-b2bb-a8a738747cb9" alt="app" width="250"/>
</p>

## Tested Devices

- reMarkable Paper Pro Move


## How to Install

### Recommended Install Script

SSH into your reMarkable as `root`, then run:

```bash
wget -O install.sh https://raw.githubusercontent.com/paviro/Syncthing-for-reMarkable/main/install.sh
sh install.sh
```

The script checks whether Vellum is already installed. If Vellum is missing, it downloads and runs the Vellum bootstrap script, then installs AppLoad with Vellum, starts XOVI/AppLoad, downloads the latest Syncthing for reMarkable release, and installs it to:

```
/home/root/xovi/exthome/appload/syncthing
```

The script prompts before making changes. If an older Syncthing app install exists, the script treats the run as an app update: it preserves the installed Syncthing binary and local `config.json` when present, then replaces the old app files.

### Manual Installation

Use these steps if you prefer not to use the install script. First install the AppLoad/XOVI prerequisites, then install Syncthing for reMarkable manually.

#### Install prerequisites with Vellum

The recommended way to install the AppLoad/XOVI prerequisites is [Vellum](https://remarkable.guide/guide/software/vellum.html), the community package manager for reMarkable tablets. Vellum handles package dependencies and device/OS compatibility checks for the packages it installs.

1. **Set up SSH access**

   Set up SSH access to your reMarkable if you have not already done so.

2. **Install Vellum**

   Follow the [Vellum installation instructions](https://github.com/vellum-dev/vellum-cli#installation) on your reMarkable.

3. **Install AppLoad**

   Use Vellum to install AppLoad:

   ```bash
   vellum update
   vellum add appload
   ```

   Read the command output carefully. Vellum may print additional steps depending on your device and OS version.

4. **Rebuild the XOVI hash table**

   Rebuild the hash table after installing or updating AppLoad/XOVI packages:

   ```bash
   xovi/rebuild_hashtable
   ```

5. **Start XOVI/AppLoad**

   Start XOVI after installing AppLoad, and after each reboot if you have not configured an automatic start method:

   ```bash
   xovi/start
   ```

#### Install prerequisites without Vellum

If you cannot use Vellum, you can install the prerequisites manually:

1. **Install XOVI manually**
   
   Install XOVI from [https://github.com/asivery/rm-xovi-extensions](https://github.com/asivery/rm-xovi-extensions) by using the included installation script.

2. **Install required extensions manually**
   
   Install `qt-resource-rebuilder` (from the XOVI repo) and `rm-appload`:
   
   ```bash
   # Copy the required extensions to the XOVI extensions directory
   cp qt-resource-rebuilder.so /home/root/xovi/extensions.d/
   cp appload.so /home/root/xovi/extensions.d/
   ```

3. **Rebuild the hash table**
   
   ```bash
   xovi/rebuild_hashtable
   ```

4. **Start XOVI**
   
   Run XOVI (you must do this every time you reboot your device):
   
   ```bash
   xovi/start
   ```

#### Install Syncthing for reMarkable

1. **Download Syncthing for reMarkable**
   
   Download the [latest release](https://github.com/paviro/Syncthing-for-reMarkable/releases) of Syncthing for reMarkable and pick the archive that matches your device:
   - **reMarkable Paper Pro / Paper Pro Move** → `syncthing-rm-appload-aarch64.zip`
   - **reMarkable 2** → `syncthing-rm-appload-armv7.zip` (32-bit build, currently untested)

2. **Extract and Copy Files**
   
   Extract the archive and copy the `syncthing` folder to `/home/root/xovi/exthome/appload/` so that it remains as:
   
   ```
   /home/root/xovi/exthome/appload/syncthing
   ```
   
   > **Note:** Most users can ignore the `config.sample.json` file when using the auto-installer - it's not needed! The auto-installer handles everything automatically. This configuration file is only for advanced users who want to manually manage their Syncthing installation.

3. **Launch Syncthing**
   
   - Open the sidebar on your reMarkable
   - Touch "AppLoad"
   - Launch Syncthing from the AppLoad menu

4. **Closing the App**
   
   To close the app, swipe down from the center top of the screen to display the AppLoad window controls and tap the X button.

## Accessing the Syncthing Web Interface

### Via USB Connection (Default)

When your reMarkable device is connected via USB, you can access the Syncthing web interface at:

```
http://10.11.99.1:8384
```

Simply open this URL in your web browser while your device is connected.

### Via Network (Optional)

To access Syncthing over your local network:

1. Open the Syncthing app on your reMarkable
2. Tap the **gear icon** (⚙️) at the top right to open Settings
3. Enable **Network Access**
4. Access the web interface using your device's IP address:
   ```
   http://<device-ip>:8384
   ```
   
   Replace `<device-ip>` with your reMarkable's IP address on your local network.

> **⚠️ Security Note:** When enabling network access, it's strongly recommended to:
> - **Set a password** in the Syncthing web interface (Settings → GUI → GUI Authentication)
> - **Enable HTTPS** in the Syncthing web interface (Settings → GUI → Use HTTPS for GUI)
> 
> This ensures your Syncthing instance is protected when accessible over the network.

## Debugging and Logs

If you encounter issues or want to monitor the app's behavior, you can view the logs on your reMarkable device using SSH.

### Real-time Logs

**Backend logs** (application logic and Syncthing operations):

```bash
journalctl -f | grep -i 'appload\|syncthing'
```

**Frontend logs** (UI and QML-related messages):

```bash
journalctl -f | grep -i 'qml\|syncthing-monitor'
```

> **Tip:** The `-f` flag follows the log output in real-time. Press `Ctrl+C` to stop viewing logs.

### Historical Logs

To view the last 500 log entries:

**Backend history:**

```bash
journalctl -n 500 | grep -i 'appload\|syncthing'
```

**Frontend history:**

```bash
journalctl -n 500 | grep -i 'qml\|syncthing'
```
