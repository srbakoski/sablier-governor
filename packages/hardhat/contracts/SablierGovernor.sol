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

	function supportsInterface(
		bytes4 interfaceId
	) public view override(Governor, GovernorTimelockControl) returns (bool) {
		return super.supportsInterface(interfaceId);
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
		uint256 streamVotes;

		StreamParams[] memory streams = abi.decode(params, (StreamParams[]));
		if (streams.length == 0) {
			streamVotes = 0;
		} else {
			for (uint256 i = 0; i < streams.length; i++) {
				uint256 streamId = streams[i].streamID;

				if (streams[i].streamType == StreamType.Linear) {
					// @dev Reverts if `streamId` references a null stream.
					LockupLinear.Stream memory stream = i_sablierLinear
						.getStream(streamId);

					// add if stream was already used for voting
					if (address(stream.asset) != address(token)) {
						continue;
					}

					if (i_sablierLinear.getRecipient(streamId) != account) {
						revert("Recipient does not match account");
					}

					if (stream.wasCanceled) {
						streamVotes += i_sablierLinear.withdrawableAmountOf(
							streamId
						);
					} else {
						streamVotes +=
							stream.amounts.deposited -
							stream.amounts.withdrawn;
					}
				} else {
					// @dev Reverts if `streamId` references a null stream.
					LockupDynamic.Stream memory stream = i_sablierDynamic
						.getStream(streamId);

					// add if stream was already used for voting
					// add last valid stream check
					if (address(stream.asset) != address(token)) {
						continue;
					}

					if (i_sablierDynamic.getRecipient(streamId) != account) {
						revert("Recipient does not match account");
					}

					if (stream.wasCanceled) {
						streamVotes += i_sablierDynamic.withdrawableAmountOf(
							streamId
						);
					} else {
						streamVotes +=
							stream.amounts.deposited -
							stream.amounts.withdrawn;
					}
				}
			}
		}

		return regularVotes + streamVotes;
	}
}
