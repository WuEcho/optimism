// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

// Contracts
import { CrossDomainMessenger } from "src/universal/CrossDomainMessenger.sol";

// Libraries
import { Predeploys } from "src/libraries/Predeploys.sol";
import { GasPayingToken } from "src/libraries/GasPayingToken.sol";
import { Constants } from "src/libraries/Constants.sol";

// Interfaces
import { ISemver } from "interfaces/universal/ISemver.sol";
import { ISuperchainConfig } from "interfaces/L1/ISuperchainConfig.sol";
import { IOptimismPortal2 as IOptimismPortal } from "interfaces/L1/IOptimismPortal2.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @custom:proxied true
/// @title L1CrossDomainMessenger
/// @notice The L1CrossDomainMessenger is a message passing interface between L1 and L2 responsible
///         for sending and receiving data on the L1 side. Users are encouraged to use this
///         interface instead of interacting with lower-level contracts directly.
contract L1CrossDomainMessenger is CrossDomainMessenger, ISemver {
    /// @notice Allows for interactions with non standard ERC20 tokens.
    using SafeERC20 for IERC20;

    /// @notice Contract of the SuperchainConfig.
    ISuperchainConfig public superchainConfig;

    /// @notice Contract of the OptimismPortal.
    /// @custom:network-specific
    IOptimismPortal public portal;

    /// @custom:legacy
    /// @custom:spacer systemConfig
    /// @notice Spacer taking up the legacy `systemConfig` slot.
    address private spacer_253_0_20;

    /// @notice Semantic version.
    /// @custom:semver 2.5.0
    string public constant version = "2.5.0";

    /// @notice Constructs the L1CrossDomainMessenger contract.
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the contract.
    /// @param _superchainConfig Contract of the SuperchainConfig contract on this network.
    /// @param _portal Contract of the OptimismPortal contract on this network.
    function initialize(ISuperchainConfig _superchainConfig, IOptimismPortal _portal) external initializer {
        superchainConfig = _superchainConfig;
        portal = _portal;
        __CrossDomainMessenger_init({ _otherMessenger: CrossDomainMessenger(Predeploys.L2_CROSS_DOMAIN_MESSENGER) });
    }

    /// @notice Getter function for the OptimismPortal contract on this chain.
    ///         Public getter is legacy and will be removed in the future. Use `portal()` instead.
    /// @return Contract of the OptimismPortal on this chain.
    /// @custom:legacy
    function PORTAL() external view returns (IOptimismPortal) {
        return portal;
    }

    /// @notice Checks if the chain is using a custom gas token
    /// @return True if the chain is using a custom gas token
    function _isCustomGasToken() internal view returns (bool) {
        (address addr,) = GasPayingToken.getToken();
        return addr != Constants.ETHER;
    }

    /// @inheritdoc CrossDomainMessenger
    function _sendMessage(address _to, uint64 _gasLimit, uint256 _value, bytes memory _data) internal override {
        if (_isCustomGasToken()) {
            // If using a custom gas token, we need to check if the user is trying to send ETH
            require(_value == 0, "L1CrossDomainMessenger: cannot send ETH on custom gas token chain");

            // For custom gas token chains, use depositERC20Transaction
            (address tokenAddr,) = GasPayingToken.getToken();

            // Handle approval for the token
            if (msg.value > 0) {
                // Approve the token for the Portal to transfer
                IERC20(tokenAddr).safeApprove(address(portal), msg.value);

                // Call depositERC20Transaction instead
                (bool success, bytes memory returnData) = address(portal).call(
                    abi.encodeWithSignature(
                        "depositERC20Transaction(address,uint256,uint256,uint64,bool,bytes)",
                        _to,
                        msg.value, // mint amount
                        _value, // value to pass (should be 0)
                        _gasLimit,
                        false, // not a contract creation
                        _data
                    )
                );

                require(success, string(returnData));
            } else {
                // If no value to send, just call the standard depositTransaction
                portal.depositTransaction({ _to: _to, _value: 0, _gasLimit: _gasLimit, _isCreation: false, _data: _data });
            }
        } else {
            // For ETH chains, use standard depositTransaction
            portal.depositTransaction{ value: _value }({
                _to: _to,
                _value: _value,
                _gasLimit: _gasLimit,
                _isCreation: false,
                _data: _data
            });
        }
    }

    /// @inheritdoc CrossDomainMessenger
    function _isOtherMessenger() internal view override returns (bool) {
        return msg.sender == address(portal) && portal.l2Sender() == address(otherMessenger);
    }

    /// @inheritdoc CrossDomainMessenger
    function _isUnsafeTarget(address _target) internal view override returns (bool) {
        return _target == address(this) || _target == address(portal);
    }

    /// @inheritdoc CrossDomainMessenger
    function paused() public view override returns (bool) {
        return superchainConfig.paused();
    }
}
