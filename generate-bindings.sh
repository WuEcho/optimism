#!/bin/bash

set -e
set -o pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 打印带颜色的消息
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查必要的工具
check_dependencies() {
    print_info "检查依赖..."

    if ! command -v abigen &> /dev/null; then
        print_error "abigen 未找到，请安装 go-ethereum"
        exit 1
    fi

    if ! command -v forge &> /dev/null; then
        print_error "forge 未找到，请安装 foundry"
        exit 1
    fi

    if ! command -v jq &> /dev/null; then
        print_error "jq 未找到，请安装 jq"
        exit 1
    fi

    print_info "所有依赖已满足"
}

# 构建合约
build_contracts() {
    print_info "构建智能合约..."
    cd packages/contracts-bedrock
    forge build
    cd ../..
    print_info "合约构建完成"
}

# 生成单个合约的绑定
generate_binding() {
    local contract_name=$1
    local package_name=$2
    local output_dir=$3

    print_info "生成 $contract_name 的绑定..."

    # 创建输出目录
    mkdir -p "$output_dir"

    # 提取ABI和字节码
    local abi_file="packages/contracts-bedrock/forge-artifacts/$contract_name.sol/$contract_name.json"
    local abi_output="$output_dir/${package_name}.abi"
    local bin_output="$output_dir/${package_name}.bin"
    local go_output="$output_dir/${package_name}.go"

    if [ ! -f "$abi_file" ]; then
        print_warning "找不到 $abi_file，跳过 $contract_name"
        return 0
    fi

    # 提取ABI
    jq '.abi' "$abi_file" > "$abi_output"

    # 提取字节码
    jq -r '.bytecode.object' "$abi_file" > "$bin_output"

    # 生成Go绑定
    abigen \
        --abi "$abi_output" \
        --bin "$bin_output" \
        --pkg "$package_name" \
        --out "$go_output" \
        --type "$contract_name"

    # 清理临时文件
    rm "$abi_output" "$bin_output"

    print_info "$contract_name 绑定生成完成: $go_output"
}

# 生成StandardValidator的多个版本绑定
generate_standardvalidator_bindings() {
    local output_dir=$1

    print_info "生成 StandardValidator 的多个版本绑定..."

    # 定义StandardValidator的版本
    local versions=(
        "StandardValidatorBase:standardvalidatorbase"
        "StandardValidatorV180:standardvalidatorv180"
        "StandardValidatorV200:standardvalidatorv200"
    )

    for version_pair in "${versions[@]}"; do
        IFS=':' read -r contract_name package_name <<< "$version_pair"

        print_info "生成 $contract_name 的绑定..."

        # 创建输出目录
        mkdir -p "$output_dir"

        # 提取ABI和字节码
        local abi_file="packages/contracts-bedrock/forge-artifacts/StandardValidator.sol/$contract_name.json"
        local abi_output="$output_dir/${package_name}.abi"
        local bin_output="$output_dir/${package_name}.bin"
        local go_output="$output_dir/${package_name}.go"

        if [ ! -f "$abi_file" ]; then
            print_warning "找不到 $abi_file，跳过 $contract_name"
            continue
        fi

        # 提取ABI
        jq '.abi' "$abi_file" > "$abi_output"

        # 提取字节码
        jq -r '.bytecode.object' "$abi_file" > "$bin_output"

        # 生成Go绑定
        abigen \
            --abi "$abi_output" \
            --bin "$bin_output" \
            --pkg "$package_name" \
            --out "$go_output" \
            --type "$contract_name"

        # 清理临时文件
        rm "$abi_output" "$bin_output"

        print_info "$contract_name 绑定生成完成: $go_output"
    done
}

# 生成所有绑定
generate_all_bindings() {
    print_info "开始生成所有Go绑定..."

    # 定义合约列表 - 使用数组而不是关联数组
    local contracts=(
        "OptimismPortal2:optimismportal2"
        "OptimismPortalInterop:optimismportalinterop"
        "L2OutputOracle:l2outputoracle"
        "L2ToL1MessagePasser:l2tol1messagepasser"
        "DisputeGameFactory:disputegamefactory"
        "L1Block:l1block"
        "SystemConfig:systemconfig"
        "SuperchainConfig:superchainconfig"
        "L1CrossDomainMessenger:l1crossdomainmessenger"
        "L1StandardBridge:l1standardbridge"
        "L2CrossDomainMessenger:l2crossdomainmessenger"
        "L2StandardBridge:l2standardbridge"
        "GasPriceOracle:gaspriceoracle"
        "SequencerFeeVault:sequencerfeevault"
        "L1FeeVault:l1feevault"
        "BaseFeeVault:basefeevault"
        "FeeVault:feevault"
        "WETH:weth"
        "SuperchainWETH:superchainweth"
        "OptimismSuperchainERC20:optimismsuperchainerc20"
        "OptimismSuperchainERC20Factory:optimismsuperchainerc20factory"
        "OptimismSuperchainERC20Beacon:optimismsuperchainerc20beacon"
        "SuperchainERC20:superchainerc20"
        "SuperchainTokenBridge:superchaintokenbridge"
        "OptimismMintableERC721:optimismmintableerc721"
        "OptimismMintableERC721Factory:optimismmintableerc721factory"
        "L2ERC721Bridge:l2erc721bridge"
        "L1ERC721Bridge:l1erc721bridge"
        "CrossDomainOwnable:crossdomainownable"
        "CrossDomainOwnable2:crossdomainownable2"
        "CrossDomainOwnable3:crossdomainownable3"
        "CrossL2Inbox:crossl2inbox"
        "ETHLiquidity:ethliquidity"
        "DataAvailabilityChallenge:dataavailabilitychallenge"
        "OPContractsManager:opcontractsmanager"
        "OPPrestateUpdater:opprestateupdater"
        "ResourceMetering:resourcemetering"
        "ProtocolVersions:protocolversions"
    )

    # 生成每个合约的绑定
    for contract_pair in "${contracts[@]}"; do
        IFS=':' read -r contract_name package_name <<< "$contract_pair"
        output_dir="bindings-output"
        generate_binding "$contract_name" "$package_name" "$output_dir"
    done

    # 生成StandardValidator的多个版本
    generate_standardvalidator_bindings "bindings-output"

    print_info "所有绑定生成完成"
}

# 生成预览版本的绑定
generate_preview_bindings() {
    print_info "生成预览版本的绑定..."

    # 创建预览目录
    mkdir -p bindings-output/preview

    # 生成OptimismPortal2的预览版本
    generate_binding "OptimismPortal2" "optimismportal2" "bindings-output/preview"

    print_info "预览版本绑定生成完成"
}

# 清理旧的绑定文件
cleanup_old_bindings() {
    print_info "清理旧的绑定文件..."

    # 如果输出目录已存在，备份它
    if [ -d "bindings-output" ]; then
        mv bindings-output bindings-output.backup.$(date +%Y%m%d_%H%M%S)
    fi

    print_info "旧绑定文件已备份"
}

# 验证生成的绑定
validate_bindings() {
    print_info "验证生成的绑定..."

    # 检查Go文件是否可以编译
    cd bindings-output
    if go build .; then
        print_info "绑定验证成功"
    else
        print_warning "绑定验证失败，但文件已生成"
    fi
    cd ..
}

# 主函数
main() {
    print_info "开始生成Go绑定文件..."

    check_dependencies
    build_contracts
    cleanup_old_bindings
    generate_all_bindings
    generate_preview_bindings
    validate_bindings

    print_info "Go绑定文件生成完成！"
    print_info "生成的文件位于: bindings-output/"
    print_info "预览版本位于: bindings-output/preview/"
    print_info "请检查生成的文件，然后手动复制需要的文件到 op-node/bindings/ 目录"
}

# 运行主函数
main "$@"