# Teleport Wrapper Script

This bash script provides a convenient way to interact with Teleport for logging in, connecting to databases, assuming roles, requesting role access, connecting to Kubernetes clusters, and more.

## Prerequisites

Before using this script, ensure you have the following prerequisites installed:

- Teleport
- jq
- OpenSSL

### Installation

#### Mac

You can install the required packages by executing the following command:

```bash
brew install teleport jq openssl
```

#### Ubuntu/Debian (apt)

```bash
#Download Teleport's PGP public key
sudo curl https://deb.releases.teleport.dev/teleport-pubkey.asc \
  -o /usr/share/keyrings/teleport-archive-keyring.asc

#Add the Teleport APT repository
echo "deb [signed-by=/usr/share/keyrings/teleport-archive-keyring.asc] https://deb.releases.teleport.dev/ stable main" \
| sudo tee /etc/apt/sources.list.d/teleport.list > /dev/null

sudo apt-get update

sudo apt install teleport jq openssl
```

#### CentOS/RHEL (dnf)

```bash
sudo dnf config-manager --add-repo https://rpm.releases.teleport.dev/teleport.repo
sudo dnf install teleport jq openssl
```

#### Arch Linux (yay)

```bash
yay -S teleport-bin jq openssl
```

## Getting Started

1. Clone the repository containing the Teleport wrapper script:

   ```bash
   git clone git@github.com:ParamountCommerce/platform-teleport-client-scripts.git
   ```

2. Navigate to the `teleport-client-scripts` directory:

   ```bash
   cd teleport-client-scripts
   ```

3. Run the script:

   ```bash
   bash teleport.sh
   ```

## Usage

When you run the script, you will be presented with a menu of options:

1. Teleport Login
2. Connect to DB
3. Assume Role & Connect to DB
4. Request Role Access
5. Connect to Kubernetes Cluster
6. Tsh Logout
7. Migrate To V2 Script
8. Quit

Select the desired option by entering the corresponding number.

### Connecting to a Database

To connect to a database:

1. Choose option 2 from the menu.
2. Follow the prompts to select the environment and database.
3. The script will provide you with the necessary connection details.

You can now connect to the database using either the Teleport CLI or your favorite IDE (e.g., DBeaver, IntelliJ).

- Using Teleport CLI:
  ```bash
  tsh db connect <database-name>
  ```

- Using an IDE (e.g., DBeaver):
  1. Open DBeaver.
  2. Create a new connection and configure it using the provided connection details.
  3. In the "General" tab, name your DB connection.
  4. In the "PostgreSQL" tab, copy and paste the host, port, and database information.
  5. In the "SSL" tab, configure the SSL settings using the provided CA certificate, client certificate, and client private key.
  6. Click "OK" and connect to the database.

### Connecting to a Kubernetes Cluster

To connect to a Kubernetes cluster:

1. Choose option 5 from the menu.
2. Follow the prompts to select the desired cluster.
3. The script will log you in to the selected cluster.

You can now interact with the Kubernetes cluster using the \`kubectl\` command.

## Notes

- The script provides additional options for logging in, assuming roles, requesting role access, and more. Explore the menu options to utilize these features.
- Make sure to properly configure your Teleport authentication and access settings before using this script.
- If you encounter any issues or have questions, please refer to the Teleport 
- documentation or reach out to your system administrator.
