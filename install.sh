#!/bin/bash

# This script sets up a Python 3.11 dev environment using asdf,
# configures git with SSH for GitHub, installs VSCode, minimal dependencies,
# Docker Desktop, and configures AWS CLI with SSO profiles.

echo "This program requires elevated privileges to run, use your MacBook password."
sudo echo "Successfully authenticated for elevated privileges."

# Install Homebrew (if not present)
if ! command -v brew &> /dev/null; then
  echo "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Install oh-my-zsh if not already installed
if [ -d ~/.oh-my-zsh ]; then
  echo "oh-my-zsh is installed"
else
  echo "Installing oh-my-zsh..."
  sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi
source ~/.zshrc

echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile

# Install asdf version manager
if ! command -v asdf &> /dev/null; then
  echo "Installing asdf..."
  brew install asdf
  echo -e '\n. $(brew --prefix asdf)/libexec/asdf.sh' >> ~/.zshrc
  source ~/.zshrc
fi

# Install Python plugin and Python 3.11 via asdf
echo "Setting up Python 3.11 with asdf..."
asdf plugin add python || true
asdf install python 3.11.11
asdf global python 3.11.11

# Install pip and sqlfluff
echo "Installing sqlfluff..."
pip install --upgrade pip
pip install sqlfluff

# Install VSCode
echo "Installing VSCode..."
brew install --cask visual-studio-code

# Install VSCode devcontainer extension
code --install-extension ms-vscode-remote.remote-containers
code --install-extension sqlfluff.sqlfluff

# Install Docker Desktop
echo "Installing Docker Desktop..."
brew install --cask docker

read -p "Enter your personal github email for SSH key generation: " user_email
read -p "Enter your username for git configuration: " git_user_name

# Generate SSH key for GitHub if not present
if [ ! -f ~/.ssh/id_ed25519 ]; then
  echo "Generating new SSH key for GitHub..."
  ssh-keygen -t ed25519 -C "$user_email"
  eval "$(ssh-agent -s)"
  ssh-add ~/.ssh/id_ed25519
  pbcopy < ~/.ssh/id_ed25519.pub
  echo "Public key copied to clipboard."
  echo "Please add your public key (~/.ssh/id_ed25519.pub) to your GitHub account."
  open https://github.com/settings/keys
fi

# Test SSH connection to GitHub
echo "Testing SSH connection to GitHub..."
ssh -T git@github.com || echo "SSH connection failed. Please ensure your key is added to GitHub."

# Configure git user info
if ! git config --global user.name &> /dev/null; then
  echo "Configuring git user.name and user.email..."
  git config --global user.name "$git_user_name"
  git config --global user.email "$user_email"
fi

# Install AWS CLI
if ! command -v aws &> /dev/null; then
  echo "Installing AWS CLI..."
  brew install awscli
fi

# Configure AWS CLI profiles
echo "Configuring AWS CLI profiles..."
mkdir -p ~/.aws
cat > ~/.aws/config <<'EOF'
[profile prd]
sso_start_url = https://kovi-aws.awsapps.com/start/#
sso_region = us-east-1
region = us-east-1
output = json
sso_account_id = 766251973294
sso_role_name = PowerUserAccess

[profile dev]
sso_start_url = https://kovi-aws.awsapps.com/start/#
sso_region = us-east-1
region = us-east-1
output = json
sso_account_id = 230230295059
sso_role_name = PowerUserAccess
EOF

# Validate AWS CLI SSO login and profile access
echo "Validating AWS CLI SSO login for 'prd' profile..."
aws sso login --profile prd
aws sts get-caller-identity --profile prd

echo "Validating AWS CLI SSO login for 'dev' profile..."
aws sso login --profile dev
aws sts get-caller-identity --profile dev

# Set zsh as the default shell
if [ "$SHELL" != "$(which zsh)" ]; then
  echo "Setting zsh as your default shell..."
  chsh -s "$(which zsh)"
fi

# Add AWS SSO login aliases to .zshrc if not present
ZSHRC="$HOME/.zshrc"
if [ ! -f "$ZSHRC" ]; then
  touch "$ZSHRC"
fi
if ! grep -q "alias prd=\"aws sso login --profile prd\"" "$ZSHRC"; then
  echo "alias prd=\"aws sso login --profile prd\"" >> "$ZSHRC"
fi
if ! grep -q "alias dev=\"aws sso login --profile dev\"" "$ZSHRC"; then
  echo "alias dev=\"aws sso login --profile dev\"" >> "$ZSHRC"
fi

echo "Setup complete! Python 3.11, asdf, VSCode, sqlfluff, Docker Desktop, AWS CLI, SSH for GitHub, and zsh as your default shell are ready."

echo "Restarting zsh shell to apply changes..."
exec zsh
