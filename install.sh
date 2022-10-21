echo "This program requires elevated privileges to run, use your MacBook password."
# Get elevated privileges for this session
sudo echo "Successfully authenticated for elevated privileges."

# Install brew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" <<< ''

# Install oh-my-zsh if not already installed
if [ -d ~/.oh-my-zsh ]; then
	echo "oh-my-zsh is installed"
 else
    sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
 	echo "oh-my-zsh is not installed"
fi

# Ensure brew working on m1
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
source ~/.zprofile

# Install miniconda

curl https://repo.anaconda.com/miniconda/Miniconda3-latest-MacOSX-arm64.sh -o ~/miniconda.sh
bash ~/miniconda.sh -b -p ~/miniconda

~/miniconda/bin/conda init zsh

# Install npm
brew install npm
# Install sql-formatter
npm install -g sql-formatter@11.0.1
# Install VSCode
brew install --cask visual-studio-code 
# Install vscode extensions
code --install-extension brunoventura.sqltools-athena-driver
code --install-extension eamodio.gitlens
code --install-extension donjayamanne.githistory
code --install-extension streetsidesoftware.code-spell-checker
brew install gh # Install GitHub CLI

# Create a github auth
while :
do
    [[ -f ~/.gh_auth.log ]] && \
        has_file=1 || \
        has_file=0
    [[ ($has_file > 0) && $(tail -2 ~/.gh_auth.log | grep "expired_token") ]] && \
        expired_token=1 ||
        expired_token=0
    [[ ($has_file > 0) && $(tail -2 ~/.gh_auth.log | grep "Logged in") ]] && \
        authenticated=1 ||
        authenticated=0
    [[ ((($has_file == 0)) || (($expired_token > 0))) ]] && \
        invalid_token=1 || \
        invalid_token=0

    [[ $authenticated == 1 ]] && \
        echo $(tail -2 ~/.gh_auth.log | grep "Logged in" | tail -1) && \
        gituser=$(tail -2 ~/.gh_auth.log | grep "Logged in" | tail -1 | cut -d " " -f 5) && \
        rm ~/.gh_auth.log && \
        break

    [[ $expired_token > 0 ]] && \
        printf "Your GitHub token has expired. "

    [[ $invalid_token > 0 ]] && \
        echo "A new code is being generated." && \
        rm -f ~/.gh_auth.log && \
        sh -c 'echo Y | gh auth login -p ssh  -w -s "admin:public_key" -h github.com &> ~/.gh_auth.log &' && \
        sleep 1 && \
        code=$(tail -3 ~/.gh_auth.log | \
            grep "one-time" | \
            tail -1 | \
            rev | \
            cut -c 1-9 | \
            rev ) && \
        echo "Paste the following code on your browser: $code" && \
        printf "%s" $code | pbcopy && \
        open https://github.com/login/device

    sleep 1

done

# Configure ssh for GitHub
ssh-keygen -t rsa -b 4096 -C "$gituser" -f ~/.ssh/gh_ssh_key -P ""
gh ssh-key add -t "Macbook Kovi" ~/.ssh/gh_ssh_key.pub

# Configure git repositories
mkdir ~/Repositories
cd ~/Repositories

gh repo clone kovihq/datamart
gh repo clone kovihq/data-pipeline

chsh -s $(which zsh) # Configure zsh as standard shell
