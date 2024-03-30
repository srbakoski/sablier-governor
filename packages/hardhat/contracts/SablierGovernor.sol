// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Governor, IGovernor } from "@openzeppelin/contracts/governance/Governor.sol";
import { GovernorSettings } from "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import { GovernorCountingSimple } from "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import { GovernorVotes, IVotes } from "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import { GovernorVotesQuorumFraction } from "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import { GovernorTimelockControl, TimelockController } from "@openzeppelin/contracts/governance/extensions/GovernorTimelockControl.sol";
import { ISablierLinear } from "./interfaces/ISablierLinear.sol";
import { ISablierDynamic } from "./interfaces/ISablierDynamic.sol";
import { LockupLinear, LockupDynamic } from "@sablier/v2-core/src/types/DataTypes.sol";
// TO-DO:
// Documentation

/// @title SablierGovernor
contract SablierGovernor is
	Governor,
	GovernorSettings,
	GovernorCountingSimple,
	GovernorVotes,
	GovernorVotesQuorumFraction,
	GovernorTimelockControl
{
	enum StreamType {
		Linear,
		Dynamic
	}
	struct StreamParams {
		uint256 streamID;
		StreamType streamType;
	}

	ISablierLinear public immutable i_sablierLinear;
	ISablierDynamic public immutable i_sablierDynamic;

	mapping(uint256 => uint256) public lastValidLinearStreamId; // @dev proposalId => last valid streamId
	mapping(uint256 => uint256) public lastValidDynamicStreamId; // @dev proposalId => last valid streamId

	mapping(uint256 => bool) private _linearStreamUsed; // @dev streamId => used
	mapping(uint256 => bool) private _dynamicStreamUsed; // @dev streamId => used

	constructor(
		IVotes _token,
		TimelockController _timelock,
		ISablierLinear sablierLinear,
		ISablierDynamic sablierDynamic
	)
		Governor("MyGovernor")
		GovernorSettings(7200 /* 1 day */, 50400 /* 1 week */, 0)
		GovernorVotes(_token)
		GovernorVotesQuorumFraction(4)
		GovernorTimelockControl(_timelock)
	{
		i_sablierLinear = sablierLinear;
		i_sablierDynamic = sablierDynamic;
	}

	/// @dev Propose a new proposal
	///      See {IGovernor-propose}.
	////     Stores the last valid streamId for Linear and Dynamic streams
	function propose(
		address[] memory targets,
		uint256[] memory values,
		bytes[] memory calldatas,
		string memory description
	) public virtual override(IGovernor, Governor) returns (uint256) {
		uint256 proposalId = super.propose(
			targets,
			values,
			calldatas,
			description
		);

		// adding checks if there are streams created
		if (i_sablierLinear.nextStreamId() != 0) {
			lastValidLinearStreamId[proposalId] =
				i_sablierLinear.nextStreamId() -
				1;
		}
		if (i_sablierDynamic.nextStreamId() != 0) {
			lastValidDynamicStreamId[proposalId] =
				i_sablierDynamic.nextStreamId() -
				1;
		}

		return proposalId;
	}

	// The following functions are overrides required by Solidity.
	function votingDelay()
		public
		view
		override(IGovernor, GovernorSettings)
		returns (uint256)
	{
		return super.votingDelay();
	}

	function votingPeriod()
		public
		view
		override(IGovernor, GovernorSettings)
		returns (uint256)
	{
		return super.votingPeriod();
	}

	function quorum(
		uint256 blockNumber
	)
		public
		view
		override(IGovernor, GovernorVotesQuorumFraction)
		returns (uint256)
	{
		return super.quorum(blockNumber);
	}

	function state(
		uint256 proposalId
	)
		public
		view
		override(Governor, GovernorTimelockControl)
		returns (ProposalState)
	{
		return super.state(proposalId);
	}

	function proposalThreshold()
		public
		view
		override(Governor, GovernorSettings)
		returns (uint256)
	{
		return super.proposalThreshold();
	}

	function supportsInterface(
		bytes4 interfaceId
	) public view override(Governor, GovernorTimelockControl) returns (bool) {
		return super.supportsInterface(interfaceId);
	}

	function _cancel(
		address[] memory targets,
		uint256[] memory values,
		bytes[] memory calldatas,
		bytes32 descriptionHash
	) internal override(Governor, GovernorTimelockControl) returns (uint256) {
		return super._cancel(targets, values, calldatas, descriptionHash);
	}

	function _executor()
		internal
		view
		override(Governor, GovernorTimelockControl)
		returns (address)
	{
		return super._executor();
	}

	function _execute(
		uint256 proposalId,
		address[] memory targets,
		uint256[] memory values,
		bytes[] memory calldatas,
		bytes32 descriptionHash
	) internal override(Governor, GovernorTimelockControl) {
		super._execute(proposalId, targets, values, calldatas, descriptionHash);
	}
	/// @dev See {GovernorVotes}.
	/// @dev Override the _getVotes function to include the votes from the streams
	function _getVotes(
		address account,
		uint256 timepoint,
		bytes memory params
	)
		internal
		view
		virtual
		override(Governor, GovernorVotes)
		returns (uint256)
	{
		uint256 regularVotes = super._getVotes(account, timepoint, params);
		uint256 streamVotes = 0;

		if (params.length > 0) {
			(StreamParams[] memory streams, uint256 proposalId) = abi.decode(
				params,
				(StreamParams[], uint256)
			);
			for (uint256 i = 0; i < streams.length; i++) {
				bool isLinear = streams[i].streamType == StreamType.Linear;
				streamVotes += _calculateStreamVotes(
					streams[i],
					proposalId,
					account,
					isLinear
				);
			}
		}

		return regularVotes + streamVotes;
	}

	/// @dev Calculate the votes from the streams
	function _calculateStreamVotes(
		StreamParams memory streamParam,
		uint256 proposalId,
		address account,
		bool isLinear
	) private view returns (uint256) {
		uint256 streamVotes = 0;
		uint256 streamId = streamParam.streamID;
		_validateStream(streamParam, proposalId, account, isLinear);

		if (isLinear) {
			LockupLinear.Stream memory stream = i_sablierLinear.getStream(
				streamId
			);
			streamVotes = _calculateLinearStreamVotes(streamId, stream);
		} else {
			LockupDynamic.Stream memory stream = i_sablierDynamic.getStream(
				streamId
			);
			streamVotes = _calculateDynamicStreamVotes(streamId, stream);
		}

		return streamVotes;
	}

	/// @dev Check if the stream is valid and if the recipient and asset match the account and token
	function _validateStream(
		StreamParams memory streamParam,
		uint256 proposalId,
		address account,
		bool isLinear
	) private view {
		uint256 streamId = streamParam.streamID;

		// Validate the stream ID
		if (isLinear) {
			if (streamId > lastValidLinearStreamId[proposalId]) {
				revert("Linear stream ID is invalid");
			}
			if (_linearStreamUsed[streamId]) {
				revert("Linear stream already used");
			}
		} else {
			if (streamId > lastValidDynamicStreamId[proposalId]) {
				revert("Dynamic stream ID is invalid");
			}
			if (_dynamicStreamUsed[streamId]) {
				revert("Dynamic stream already used");
			}
		}

		// Validate the recipient and asset
		address streamRecipient = isLinear
			? i_sablierLinear.getRecipient(streamId)
			: i_sablierDynamic.getRecipient(streamId);
		if (streamRecipient != account) {
			revert("Recipient does not match account");
		}

		address assetAddress = isLinear
			? address(i_sablierLinear.getStream(streamId).asset)
			: address(i_sablierDynamic.getStream(streamId).asset);
		if (assetAddress != address(token)) {
			revert("Asset does not match token");
		}
	}

	/// @dev Calculate the votes for a linear stream depending on the state
	function _calculateLinearStreamVotes(
		uint256 streamId,
		LockupLinear.Stream memory stream
	) private view returns (uint256) {
		return
			stream.wasCanceled
				? i_sablierLinear.withdrawableAmountOf(streamId)
				: stream.amounts.deposited - stream.amounts.withdrawn;
	}

	/// @dev Calculate the votes for a dynamic stream depending on the state
	function _calculateDynamicStreamVotes(
		uint256 streamId,
		LockupDynamic.Stream memory stream
	) private view returns (uint256) {
		return
			stream.wasCanceled
				? i_sablierDynamic.withdrawableAmountOf(streamId)
				: stream.amounts.deposited - stream.amounts.withdrawn;
	}

	/// @dev See {GovernorCountingSimple}.
	///      Override the _countVote function to mark the streams as used
	function _countVote(
		uint256 proposalId,
		address account,
		uint8 support,
		uint256 weight,
		bytes memory params
	) internal virtual override(Governor, GovernorCountingSimple) {
		super._countVote(proposalId, account, support, weight, params);
		(StreamParams[] memory streams, ) = abi.decode(
			params,
			(StreamParams[], uint256)
		);
		for (uint256 i = 0; i < streams.length; i++) {
			if (streams[i].streamType == StreamType.Linear) {
				_linearStreamUsed[streams[i].streamID] = true;
			} else {
				_dynamicStreamUsed[streams[i].streamID] = true;
			}
		}
	}
}
