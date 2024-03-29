// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { LockupDynamic } from "@sablier/v2-core/src/types/DataTypes.sol";

/// @title ISablierDynamic
interface ISablierDynamic {
	/// @notice Retrieves the stream's recipient.
	/// @dev Reverts if the NFT has been burned.
	/// @param streamId The stream id for the query.
	function getRecipient(
		uint256 streamId
	) external view returns (address recipient);

	/// @notice Retrieves the stream entity.
	/// @dev Reverts if `streamId` references a null stream.
	/// @param streamId The stream id for the query.
	function getStream(
		uint256 streamId
	) external view returns (LockupDynamic.Stream memory stream);

	/// @notice Calculates the amount that the recipient can withdraw from the stream, denoted in units of the asset's
	/// decimals.
	/// @dev Reverts if `streamId` references a null stream.
	/// @param streamId The stream id for the query.
	function withdrawableAmountOf(
		uint256 streamId
	) external view returns (uint128 withdrawableAmount);

	/// @notice Counter for stream ids, used in the create functions.
	function nextStreamId() external view returns (uint256);
}
