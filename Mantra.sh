#!/bin/bash

# 检查是否以root用户运行脚本
if [ "$(id -u)" != "0" ]; then
    echo "此脚本需要以root用户权限运行。"
    echo "请尝试使用 'sudo -i' 命令切换到root用户，然后再次运行此脚本。"
    exit 1
fi

# 检查并安装 Node.js 和 npm
function install_nodejs_and_npm() {
    if command -v node > /dev/null 2>&1; then
        echo "Node.js 已安装"
    else
        echo "Node.js 未安装，正在安装..."
        curl -fsSL https://deb.nodesource.com/setup_16.x | sudo -E bash -
        sudo apt-get install -y nodejs
    fi

    if command -v npm > /dev/null 2>&1; then
        echo "npm 已安装"
    else
        echo "npm 未安装，正在安装..."
        sudo apt-get install -y npm
    fi
}

# 检查并安装 PM2
function install_pm2() {
    if command -v pm2 > /dev/null 2>&1; then
        echo "PM2 已安装"
    else
        echo "PM2 未安装，正在安装..."
        npm install pm2@latest -g
    fi
}


# 节点安装功能
function install_node() {
    node_address="http://localhost:16457"
    install_nodejs_and_npm
    install_pm2

    # 检查curl是否安装，如果没有则安装
    if ! command -v curl > /dev/null; then
        sudo apt update && sudo apt install curl git -y
    fi

    # 更新和安装必要的软件
    sudo apt update && sudo apt upgrade -y
    sudo apt install curl git wget htop tmux build-essential jq make lz4 gcc unzip -y

    # 安装Go
    sudo rm -rf /usr/local/go
    curl -L https://go.dev/dl/go1.22.0.linux-amd64.tar.gz | sudo tar -xzf - -C /usr/local
    echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> $HOME/.bash_profile
    source $HOME/.bash_profile
    mkdir -p ~/go/bin

    # 安装所有二进制文件
    cd $HOME
    sudo wget -P /usr/lib https://github.com/CosmWasm/wasmvm/releases/download/v1.3.1/libwasmvm.x86_64.so
    wget https://github.com/MANTRA-Finance/public/raw/main/mantrachain-hongbai/mantrachaind-linux-amd64.zip
    unzip mantrachaind-linux-amd64.zip
    mv mantrachaind /usr/local/go/bin

    # 配置mantrachaind
    export MONIKER="My_Node"

    # 获取初始文件和地址簿
    cd $HOME
    mantrachaind init $MONIKER --chain-id mantra-hongbai-1
    mantrachaind config chain-id mantra-hongbai-1
    mantrachaind config node tcp://localhost:26657
    mantrachaind config keyring-backend os 


    

    # 配置节点
    curl -Ls https://raw.githubusercontent.com/MANTRA-Finance/public/main/mantrachain-hongbai/genesis.json > $HOME/.mantrachain/config/genesis.json


    # 下载快照
    CONFIG_TOML="$HOME/.mantrachain/config/config.toml"
    SEEDS="d6016af7cb20cf1905bd61468f6a61decb3fd7c0@34.72.142.50:26656"
    PEERS="da061f404690c5b6b19dd85d40fefde1fecf406c@34.68.19.19:26656,20db08acbcac9b7114839e63539da2802b848982@34.72.148.3:26656,7ba9e5051a1cb2542c2ecbfa12954bdbab3121f5@34.171.207.218:26656,7ab572034a2d1d9d67e31dbac43c4554e0e53ba5@104.198.160.158:26656,75855dec829d40f105299f09dc64f05b44057a3a@34.134.75.248:26656"
    sed -i.bak -e "s/^persistent_peers *=.*/persistent_peers = \"$PEERS\"/" $CONFIG_TOML
    sed -i.bak -e "s/^seeds =.*/seeds = \"$SEEDS\"/" $CONFIG_TOML

     
    # 设置用户端口
    sed -i -e "s%^proxy_app = \"tcp://127.0.0.1:26658\"%proxy_app = \"tcp://127.0.0.1:16458\"%; s%^laddr = \"tcp://127.0.0.1:26657\"%laddr = \"tcp://127.0.0.1:16457\"%; s%^pprof_laddr = \"localhost:6060\"%pprof_laddr = \"localhost:16460\"%; s%^laddr = \"tcp://0.0.0.0:26656\"%laddr = \"tcp://0.0.0.0:16456\"%; s%^prometheus_listen_addr = \":26660\"%prometheus_listen_addr = \":16466\"%" $HOME/.mantrachain/config/config.toml
    sed -i -e "s%^address = \"tcp://localhost:1317\"%address = \"tcp://0.0.0.0:16417\"%; s%^address = \":8080\"%address = \":16480\"%; s%^address = \"localhost:9090\"%address = \"0.0.0.0:16490\"%; s%^address = \"localhost:9091\"%address = \"0.0.0.0:16491\"%; s%:8545%:16445%; s%:8546%:16446%; s%:6065%:16465%" $HOME/.mantrachain/config/app.toml
    echo "export MANTRACHAIN_RPC_PORT=$node_address" >> $HOME/.bash_profile
    source $HOME/.bash_profile
    

    # 设置gas
    sed -i 's|^minimum-gas-prices *=.*|minimum-gas-prices = "0.0002uom"|g' $CONFIG_TOML

    go install cosmossdk.io/tools/cosmovisor/cmd/cosmovisor@v1.5.0
    
    curl -L https://snapshots.indonode.net/mantra-t/mantra-t-latest.tar.lz4 | lz4 -dc - | tar -xf - -C $HOME/.mantrachain
    mv $HOME/.mantrachain/priv_validator_state.json.backup $HOME/.mantrachain/data/priv_validator_state.json
    
    # 使用 pm2 重启 mantrachaind 服务并跟踪日志
    pm2 start mantrachaind -- start && pm2 save && pm2 startup

    echo '====================== 安装完成,请退出脚本后执行 source $HOME/.bash_profile 以加载环境变量==========================='
    
}

# 查看0gai 服务状态
function check_service_status() {
    pm2 list
}

# 0gai 节点日志查询
function view_logs() {
    pm2 logs mantrachaind
}

# 卸载节点功能
function uninstall_node() {
    echo "你确定要卸载Mantra 节点程序吗？这将会删除所有相关的数据。[Y/N]"
    read -r -p "请确认: " response

    case "$response" in
        [yY][eE][sS]|[yY]) 
            echo "开始卸载节点程序..."
            pm2 stop mantrachaind && pm2 delete mantrachaind
            rm -rf $HOME/.mantrachain $HOME/mantrachain $(which mantrachaind)
            echo "节点程序卸载完成。"
            ;;
        *)
            echo "取消卸载操作。"
            ;;
    esac
}

# 创建钱包
function add_wallet() {
    read -p "请输入你想设置的钱包名称: " wallet_name
    mantrachaind keys add $wallet_name
}

# 导入钱包
function import_wallet() {
    read -p "请输入你想设置的钱包名称: " wallet_name
    mantrachaind keys add $wallet_name --recover
}

# 查询余额
function check_balances() {
    read -p "请输入钱包地址: " wallet_address
    mantrachaind query bank balances "$wallet_address" --node $node_address
}

# 查看节点同步状态
function check_sync_status() {
    mantrachaind status 2>&1 --node $MANTRACHAIN_RPC_PORT | jq .SyncInfo
}

# 创建验证者
function add_validator() {

read -p "请输入您的钱包名称: " wallet_name
read -p "请输入您想设置的验证者的名字: " validator_name
read -p "请输入您的验证者详情（例如'吊毛资本'）: " details


mantrachaind tx staking create-validator \
  --amount 100000uom \
  --pubkey=$(mantrachaind tendermint show-validator) \
  --moniker=$validator_name \
  --chain-id=mantra-hongbai-1 \
  --commission-rate=0.05 \
  --commission-max-rate=0.10 \
  --commission-max-change-rate=0.01 \
  --min-self-delegation=1 \
  --from=$wallet_name \
  --identity="" \
  --website="" \
  --details="$details" \
  --gas auto \
  --gas-adjustment 1.5 \
  --fees 50uom \
  -y
  --node $node_address
}


# 给自己地址验证者质押
function delegate_self_validator() {
read -p "请输入质押代币数量: " math
read -p "请输入钱包名称: " wallet_name
mantrachaind tx staking delegate $(mantrachaind keys show $wallet_name --bech val -a)  ${math}mantrachain --from $wallet_name --gas=500000 --gas-prices=99999amantrachain -y --node $node_address

}

# 领水
function claim_test() {
read -p "请输入mantra钱包地址: " wallet_address

curl https://faucet.hongbai.mantrachain.io/send/mantra-hongbai-1/$wallet_address
}



# 主菜单
function main_menu() {
    while true; do
        clear
        echo "脚本以及教程由推特用户大赌哥 @y95277777 编写，免费开源，请勿相信收费"
        echo "================================================================"
        echo "节点社区 Telegram 群组:https://t.me/niuwuriji"
        echo "节点社区 Telegram 频道:https://t.me/niuwuriji"
        echo "节点社区 Discord 社群:https://discord.gg/GbMV5EcNWF"
        echo "退出脚本，请按键盘ctrl c退出即可"
        echo "请选择要执行的操作:"
        echo "1. 安装节点"
        echo "2. 创建钱包"
        echo "3. 导入钱包"
        echo "4. 查看钱包地址余额"
        echo "5. 查看节点同步状态"
        echo "6. 查看当前服务状态"
        echo "7. 运行日志查询"
        echo "8. 卸载节点"
        echo "9. 创建验证者"  
        echo "10. 给自己验证者地址质押代币"
        echo "11. 快捷领水（每个IP地址24小时一次）"
        read -p "请输入选项（1-11）: " OPTION

        case $OPTION in
        1) install_node ;;
        2) add_wallet ;;
        3) import_wallet ;;
        4) check_balances ;;
        5) check_sync_status ;;
        6) check_service_status ;;
        7) view_logs ;;
        8) uninstall_node ;;
        9) add_validator ;;
        10) delegate_self_validator ;;
        11) claim_test ;;
        *) echo "无效选项。" ;;
        esac
        echo "按任意键返回主菜单..."
        read -n 1
    done
    
}

# 显示主菜单
main_menu
