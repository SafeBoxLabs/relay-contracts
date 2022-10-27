// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IGelatoRelay} from "./interfaces/IGelatoRelay.sol";
import {IGelato1Balance} from "./interfaces/IGelato1Balance.sol";
import {GelatoRelayBase} from "./abstract/GelatoRelayBase.sol";
import {GelatoCallUtils} from "./lib/GelatoCallUtils.sol";
import {GelatoTokenUtils} from "./lib/GelatoTokenUtils.sol";
import {
    _encodeGelatoRelayContext,
    _encodeFeeCollector
} from "@gelatonetwork/relay-context/contracts/functions/GelatoRelayUtils.sol";
import {
    __getFeeCollector
} from "@gelatonetwork/relay-context/contracts/GelatoRelayFeeCollector.sol";
import {
    _getFeeCollectorRelayContext,
    _getFeeTokenRelayContext,
    _getFeeRelayContext
} from "@gelatonetwork/relay-context/contracts/GelatoRelayContext.sol";
import {_eip2771Context} from "./functions/ContextUtils.sol";
import {SponsoredCall, SponsoredUserAuthCall} from "./types/CallTypes.sol";
import {IGelato} from "./interfaces/IGelato.sol";

/// @title  Gelato Relay contract
/// @notice This contract deals with synchronous payments and Gelato 1Balance payments
/// @dev    This contract must NEVER hold funds!
/// @dev    Maliciously crafted transaction payloads could wipe out any funds left here
// solhint-disable-next-line max-states-count
contract GelatoRelay is IGelatoRelay, IGelato1Balance, GelatoRelayBase {
    using GelatoCallUtils for address;
    using GelatoTokenUtils for address;

    //solhint-disable-next-line const-name-snakecase
    string public constant name = "GelatoRelay";
    //solhint-disable-next-line const-name-snakecase
    string public constant version = "1";

    // solhint-disable-next-line no-empty-blocks
    constructor(address _gelato) GelatoRelayBase(_gelato) {}

    /// @dev Previous version kept for backward compatibility
    function callWithSyncFee(
        address _target,
        bytes calldata _data,
        address _feeToken,
        uint256 _fee,
        bytes32 _taskId
    ) external onlyGelato {
        uint256 preBalance = _feeToken.getBalance(address(this));

        _target.revertingContractCall(
            _encodeGelatoRelayContext(_data, msg.sender, _feeToken, _fee),
            "GelatoRelay.callWithSyncFee:"
        );

        uint256 postBalance = _feeToken.getBalance(address(this));

        uint256 fee = postBalance - preBalance;

        _feeToken.transfer(msg.sender, fee);

        emit LogCallWithSyncFee(_target, _feeToken, _fee, _taskId);
    }

    /// @notice Relay call with Synchronous Payment
    /// @notice The target contract pays Gelato during the call forward
    /// @dev    This is the most straightforward use case, and `transfer` handles token payments.
    /// @param _target Target smart contract
    /// @param _data Payload for call on _target
    /// @param _relayContext true: all relay context encoding, false: only feeCollector encoding
    /// @param _correlationId Unique task identifier generated by gelato
    function callWithSyncFeeV2(
        address _target,
        bytes calldata _data,
        bool _relayContext,
        bytes32 _correlationId
    ) external onlyGelato {
        _relayContext
            ? _target.revertingContractCall(
                _encodeGelatoRelayContext(
                    _data,
                    _getFeeCollectorRelayContext(),
                    _getFeeTokenRelayContext(),
                    _getFeeRelayContext()
                ),
                "GelatoRelay.callWithSyncFeeV2:"
            )
            : _target.revertingContractCall(
                _encodeFeeCollector(_data, __getFeeCollector()),
                "GelatoRelay.callWithSyncFeeV2:"
            );

        emit LogCallWithSyncFeeV2(_target, _correlationId);
    }

    /// @notice Relay call + One Balance payment - with sponsor authentication
    /// @notice Sponsor signature allows for payment via sponsor's 1Balance balance
    /// @dev    Payment is handled with off-chain accounting using Gelato's 1Balance system
    /// @param _call Relay call data packed into SponsoredCall struct
    /// @notice Oracle value for exchange rate between native tokens and fee token
    /// @param  _nativeToFeeTokenXRateNumerator Exchange rate numerator
    /// @param  _nativeToFeeTokenXRateDenominator Exchange rate denominator
    /// @param _correlationId Unique task identifier generated by gelato
    // solhint-disable-next-line function-max-lines
    function sponsoredCall(
        SponsoredCall calldata _call,
        address _sponsor,
        address _feeToken,
        uint256 _oneBalanceChainId,
        uint256 _nativeToFeeTokenXRateNumerator,
        uint256 _nativeToFeeTokenXRateDenominator,
        bytes32 _correlationId
    ) external onlyGelato {
        // CHECKS
        _requireChainId(_call.chainId, "GelatoRelay.sponsoredCall:");

        // INTERACTIONS
        _call.target.revertingContractCall(
            _call.data,
            "GelatoRelay.sponsoredCall:"
        );

        emit LogUseGelato1Balance(
            _sponsor,
            _call.target,
            _feeToken,
            _oneBalanceChainId,
            _nativeToFeeTokenXRateNumerator,
            _nativeToFeeTokenXRateDenominator,
            _correlationId
        );
    }

    /// @notice Relay call + One Balance payment - with BOTH sponsor and user authentication
    /// @notice Both sponsor and user signature allows for payment via sponsor's 1Balance balance
    /// @dev    Payment is handled with off-chain accounting using Gelato's 1Balance system
    /// @dev    The userNonce abstraction does not support multiple calls (call concurrency)
    /// @dev    Apps that need concurrent user calls will need to implement multi-calling
    /// @dev    on their end via encoding into _call.data.
    /// @param _call Relay call data packed into SponsoredUserAuthCall struct
    /// @param _userSignature EIP-712 compliant signature from _call.user
    /// @param  _nativeToFeeTokenXRateNumerator Exchange rate numerator
    /// @param  _nativeToFeeTokenXRateDenominator Exchange rate denominator
    /// @param _correlationId Unique task identifier generated by gelato
    // solhint-disable-next-line function-max-lines
    function sponsoredUserAuthCall(
        SponsoredUserAuthCall calldata _call,
        address _sponsor,
        address _feeToken,
        uint256 _oneBalanceChainId,
        bytes calldata _userSignature,
        uint256 _nativeToFeeTokenXRateNumerator,
        uint256 _nativeToFeeTokenXRateDenominator,
        bytes32 _correlationId
    ) external onlyGelato {
        // CHECKS
        _requireChainId(_call.chainId, "GelatoRelay.sponsoredUserAuthCall:");

        uint256 storedUserNonce = userNonce[_call.user];

        // For the user, we enforce nonce ordering
        _requireUserBasics(
            _call.userNonce,
            storedUserNonce,
            _call.userDeadline,
            "GelatoRelay.sponsoredUserAuthCall:"
        );

        bytes32 domainSeparator = _getDomainSeparator();

        // Verify user's signature
        _requireSponsoredUserAuthCallSignature(
            domainSeparator,
            _call,
            _userSignature,
            _call.user
        );

        // EFFECTS
        userNonce[_call.user] = storedUserNonce + 1;

        // INTERACTIONS
        _call.target.revertingContractCall(
            _eip2771Context(_call.data, _call.user),
            "GelatoRelay.sponsoredUserAuthCall:"
        );

        emit LogUseGelato1Balance(
            _sponsor,
            _call.target,
            _feeToken,
            _oneBalanceChainId,
            _nativeToFeeTokenXRateNumerator,
            _nativeToFeeTokenXRateDenominator,
            _correlationId
        );
    }

    //solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view returns (bytes32) {
        return _getDomainSeparator();
    }

    function _getDomainSeparator() internal view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    keccak256(
                        bytes(
                            //solhint-disable-next-line max-line-length
                            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                        )
                    ),
                    keccak256(bytes(name)),
                    keccak256(bytes(version)),
                    block.chainid,
                    address(this)
                )
            );
    }
}
