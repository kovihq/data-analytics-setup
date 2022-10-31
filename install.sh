echo "This program requires elevated privileges to run, use your MacBook password."
# Get elevated privileges for this session
sudo echo "Successfully authenticated for elevated privileges."

# Install brew
echo "Install brew"
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" <<< ''

# Install oh-my-zsh if not already installed
echo "Install oh-my-zsh"
if [ -d ~/.oh-my-zsh ]; then
	echo "oh-my-zsh is installed"
 else
    sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
 	echo "oh-my-zsh is not installed"
fi

source ~/.zshrc

# Ensure brew working on m1
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
# source ~/.zprofile


# Install miniconda
echo "Install miniconda"
curl https://repo.anaconda.com/miniconda/Miniconda3-latest-MacOSX-arm64.sh -o ~/miniconda.sh
bash ~/miniconda.sh -b -p ~/miniconda

~/miniconda/bin/conda init zsh

source ~/.zshrc

# Create Miniconda
echo "Create miniconda env"
conda create -n kovi_prod python=3 -y
conda install -n kovi_prod -c conda-forge awscli -y
conda install -n kovi_prod boto3 -y

# Install npm
echo "Install npm"
brew install npm

# Install sql-formatter
echo "Install sql-formatter"
npm install -g sql-formatter@11.0.1

# Install VSCode
echo "Install VSCode"
brew install --cask visual-studio-code
brew install jq

# Change default csv editor to VSCode
echo "Change default csv editor to VSCode"
brew install duti
duti -s code .csv all


# Install vscode extensions
echo "Install vscode extensions"
code --install-extension brunoventura.sqltools-athena-driver
code --install-extension eamodio.gitlens
code --install-extension donjayamanne.githistory
code --install-extension streetsidesoftware.code-spell-checker
code --install-extension ms-vsliveshare.vsliveshare
code --install-extension randomfractalsinc.vscode-data-preview

# Configure sqltools
echo "Configure sqltools"
usersettingspath=~/Library/Application\ Support/Code/User/settings.json
if [ ! -f $usersettingspath ]
then
    touch $usersettingspath
    echo "{}" > $usersettingspath
fi

conda activate kovi_prod

# Get AWS Access
while :
do
  echo -n "Please enter your accessKeyId: "
  read accesskeyid
  echo -n "Please enter your secretAccessKey: "
  read secretaccesskey
  echo -n "Please enter your region: "
  read region

  echo " "
  echo "AccessKeyId: $accesskeyid."
  echo "SecretAccessKey: $secretaccesskey."
  echo "Region: $region."
  echo " "
  
  aws configure set aws_access_key_id $accesskeyid
  aws configure set aws_secret_access_key $secretaccesskey
  aws configure set region $region

  tmp=$(mktemp)
  aws athena start-query-execution \
      --query-string "SELECT 1" \
      --work-group "primary" \
      --query-execution-context Database=cflogsdatabase,Catalog=AwsDataCatalog &> $tmp

  access=$(perl -pe 's/\n//' $tmp | awk -F"[()]" '{print $2}')

  if [[ $access != "AccessDeniedException" && $access != "UnrecognizedClientException" ]]; 
  then
    break
  fi
  echo "Error logging ($access)."
  echo "Try again."

done

# Update settings.json
tmp=$(mktemp)
jq --arg accessKeyId "$accesskeyid" \
--arg secretAccessKey "$secretaccesskey" \
--arg Region "$region" \
'."sqltools.connections"=[
    {
        "previewLimit": 50,
        "driver": "driver.athena",
        "name": "Athena Prod",
        "workgroup": "primary",
        "accessKeyId": $accessKeyId,
        "secretAccessKey": $secretAccessKey,
        "region": $Region
    }
] | 
."sqltools.useNodeRuntime"= true' "$usersettingspath" > "$tmp" && mv "$tmp" "$usersettingspath"

conda deactivate

# Install GitHub CLI
echo "Install GitHub CLI"
brew install gh 

# Create a github auth
echo "Configure GitHub CLI"
rm -f ~/.gh_auth.log
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
        sh -c 'echo Y | gh auth login -p https  -w -s "admin:public_key" -h github.com &> ~/.gh_auth.log &' && \
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
gh auth setup-git

# Configure git repositories
echo "Configure git repositories"
mkdir ~/Repositories
cd ~/Repositories


gh repo clone kovihq/datamart
gh repo clone kovihq/data-pipeline

chsh -s $(which zsh) # Configure zsh as standard shell
