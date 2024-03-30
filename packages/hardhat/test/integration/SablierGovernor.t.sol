// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";
import { ERC20Token } from "../../contracts/mock/ERC20Token.sol";
import { Greeting } from "../../contracts/mock/Greeting.sol";
import { Timelock } from "../../contracts/Timelock.sol";
import { SablierGovernor } from "../../contracts/SablierGovernor.sol";
import { ud60x18 } from "@prb/math/src/UD60x18.sol";
import { ud2x18 } from "@prb/math/src/UD2x18.sol";
import { ISablierLinear } from "../../contracts/interfaces/ISablierLinear.sol";
import { ISablierDynamic } from "../../contracts/interfaces/ISablierDynamic.sol";
import { Broker, LockupLinear, LockupDynamic } from "@sablier/v2-core/src/types/DataTypes.sol";

contract SablierGovernorTest is Test {
	// Token decimals
	uint256 constant DECIMALS = 18;

	address public immutable i_deployerAddress;
	// Arbitrum one addresses
	ISablierLinear public immutable i_sablierLinear =
		ISablierLinear(0xFDD9d122B451F549f48c4942c6fa6646D849e8C1);
	ISablierDynamic public immutable i_sablierDynamic =
		ISablierDynamic(0xf390cE6f54e4dc7C5A5f7f8689062b7591F7111d);

	uint256 latestProposalId;
	uint256 latestLinearStreamId;
	uint256 latestDynamicStreamId;

	address testAddress = makeAddr("testAddress");

	ERC20Token public erc20Token;
	Greeting public greeting;
	Timelock public timelock;
	SablierGovernor public sablierGovernor;

	modifier createLinearStream() {
		// Total mint amount
		uint256 totalAmount = 1000 * (10 ** DECIMALS);
		erc20Token.mint(i_deployerAddress, totalAmount);

		vm.prank(i_deployerAddress);
		erc20Token.approve(address(this), totalAmount);
		// Transfer the provided amount of DAI tokens to this contract
		erc20Token.transferFrom(i_deployerAddress, address(this), totalAmount);

		// Approve the Sablier contract to spend DAI
		erc20Token.approve(address(i_sablierLinear), totalAmount);

		// Declare the params struct
		LockupLinear.CreateWithDurations memory params;

		// Declare the function parameters
		params.sender = i_deployerAddress; // The sender will be able to cancel the stream
		params.recipient = testAddress; // The recipient of the streamed assets
		params.totalAmount = uint128(totalAmount); // Total amount is the amount inclusive of all fees
		params.asset = erc20Token; // The streaming asset
		params.cancelable = true; // Whether the stream will be cancelable or not
		params.durations = LockupLinear.Durations({
			cliff: 4 weeks, // Assets will be unlocked only after 4 weeks
			total: 52 weeks // Setting a total duration of ~1 year
		});
		params.broker = Broker(address(0), ud60x18(0)); // Optional parameter for charging a fee

		// Create the LockupLinear stream using a function that sets the start time to `block.timestamp`
		latestLinearStreamId = i_sablierLinear.createWithDurations(params);
		_;
	}
	modifier createDynamicStream() {
		// Segment zero amount
		uint256 amount0 = 0;
		// Segment one amount
		uint256 amount1 = 3000 * (10 ** DECIMALS);
		// Total mint amount
		uint256 totalAmount = amount0 + amount1;

		erc20Token.mint(i_deployerAddress, totalAmount);

		vm.prank(i_deployerAddress);
		erc20Token.approve(address(this), totalAmount);

		// Transfer the provided amount of DAI tokens to this contract
		erc20Token.transferFrom(i_deployerAddress, address(this), totalAmount);

		// Approve the Sablier contract to spend DAI
		erc20Token.approve(address(i_sablierDynamic), totalAmount);

		// Declare the params struct
		LockupDynamic.CreateWithMilestones memory params;

		// Declare the function parameters
		params.sender = i_deployerAddress; // The sender will be able to cancel the stream
		params.recipient = testAddress; // The recipient of the streamed assets
		params.totalAmount = uint128(totalAmount); // Total amount is the amount inclusive of all fees
		params.asset = erc20Token; // The streaming asset
		params.cancelable = true; // Whether the stream will be cancelable or not
		params.startTime = uint40(block.timestamp + 100 seconds);
		params.broker = Broker(address(0), ud60x18(0)); // Optional parameter left undefined

		// Declare some dummy segments
		params.segments = new LockupDynamic.Segment[](2);
		params.segments[0] = LockupDynamic.Segment({
			amount: uint128(amount0),
			exponent: ud2x18(1e18),
			milestone: uint40(block.timestamp + 4 weeks)
		});
		params.segments[1] = (
			LockupDynamic.Segment({
				amount: uint128(amount1),
				exponent: ud2x18(3.14e18),
				milestone: uint40(block.timestamp + 52 weeks)
			})
		);

		// Create the LockupDynamic stream
		latestDynamicStreamId = i_sablierDynamic.createWithMilestones(params);
		_;
	}

	modifier createProposal() {
		address[] memory targets = new address[](1);
		uint256[] memory values = new uint256[](1);
		bytes[] memory calldatas = new bytes[](1);
		string memory description = "Change greeting to Hello Bucharest";
		targets[0] = address(greeting);
		values[0] = 0;
		calldatas[0] = abi.encodeWithSignature(
			"setGreeting(string)",
			"Hello Bucharest"
		);
		latestProposalId = sablierGovernor.propose(
			targets,
			values,
			calldatas,
			description
		);
		_;
	}

	constructor() {
		i_deployerAddress = msg.sender;
	}

	function setUp() external {
		vm.createSelectFork("https://arb1.arbitrum.io/rpc");

		vm.startPrank(i_deployerAddress);
		erc20Token = new ERC20Token();
		address[] memory proposers = new address[](1);
		address[] memory executors = new address[](1);
		timelock = new Timelock(
			1 days,
			proposers,
			executors,
			i_deployerAddress
		);
		greeting = new Greeting(address(timelock));
		sablierGovernor = new SablierGovernor(
			erc20Token,
			timelock,
			i_sablierLinear,
			i_sablierDynamic
		);
		timelock.grantRole(timelock.CANCELLER_ROLE(), address(sablierGovernor));
		timelock.grantRole(timelock.PROPOSER_ROLE(), address(sablierGovernor));
		timelock.grantRole(timelock.EXECUTOR_ROLE(), address(0));
		timelock.revokeRole(timelock.TIMELOCK_ADMIN_ROLE(), i_deployerAddress);

		vm.stopPrank();
	}

	function test_deployment() external view {
		assertEq(
			address(sablierGovernor.i_sablierLinear()),
			address(i_sablierLinear)
		);
		assertEq(
			address(sablierGovernor.i_sablierDynamic()),
			address(i_sablierDynamic)
		);
	}

	function test_propose()
		external
		createLinearStream
		createDynamicStream
		createProposal
	{
		assertEq(
			sablierGovernor.lastValidLinearStreamId(latestProposalId),
			i_sablierLinear.nextStreamId() - 1
		);
		assertEq(
			sablierGovernor.lastValidDynamicStreamId(latestProposalId),
			i_sablierDynamic.nextStreamId() - 1
		);
	}

	function test_getVotes()
		external
		createLinearStream
		createDynamicStream
		createProposal
	{
		// createLinearStream creates stream with 1000 tokens inside of it
		// createDynamicStream creates stream with 3000 tokens inside of it
		// Additional 1000 tokens will be minted to the testAddress, which represents maxVotingPower of 5000 tokens
		uint256 maxVotingPower = 5000 * (10 ** DECIMALS);

		// we mint additional 1000 tokens to the testAddress
		erc20Token.mint(testAddress, 1000 * (10 ** DECIMALS));
		uint256 testAddressBalance = erc20Token.balanceOf(testAddress);

		uint256 regularVotingPower = erc20Token.balanceOf(testAddress);
		vm.roll(block.number + 2);

		// voting power without streams
		uint256 votingPower = sablierGovernor.getVotes(
			testAddress,
			block.number - 1
		);
		assertEq(regularVotingPower, votingPower);

		// create params for getVotesWithParams
		uint256 proposalId = latestProposalId;
		SablierGovernor.StreamParams[]
			memory streamParams = new SablierGovernor.StreamParams[](2);
		streamParams[0] = SablierGovernor.StreamParams(
			latestLinearStreamId,
			SablierGovernor.StreamType.Linear
		);
		streamParams[1] = SablierGovernor.StreamParams(
			latestDynamicStreamId,
			SablierGovernor.StreamType.Dynamic
		);

		bytes memory params = abi.encode(streamParams, proposalId);

		votingPower = sablierGovernor.getVotesWithParams(
			testAddress,
			block.number - 1,
			params
		);

		assertEq(maxVotingPower, votingPower);

		vm.warp(block.timestamp + 6 weeks);
		vm.startPrank(testAddress);

		// withdrawable amount from linear stream
		uint128 withdrawableAmountAfterSixWeeks = i_sablierLinear
			.withdrawableAmountOf(latestLinearStreamId);

		i_sablierLinear.withdraw(
			latestLinearStreamId,
			testAddress,
			withdrawableAmountAfterSixWeeks
		);

		votingPower = sablierGovernor.getVotesWithParams(
			testAddress,
			block.number - 1,
			params
		);

		assertEq(maxVotingPower - withdrawableAmountAfterSixWeeks, votingPower);

		// end of linear stream
		vm.warp(block.timestamp + 51 weeks);

		uint128 withdrawableAmountAtTheEnd = i_sablierLinear
			.withdrawableAmountOf(latestLinearStreamId);

		i_sablierLinear.withdraw(
			latestLinearStreamId,
			testAddress,
			withdrawableAmountAtTheEnd
		);

		votingPower = sablierGovernor.getVotesWithParams(
			testAddress,
			block.number - 1,
			params
		);

		assertEq(
			maxVotingPower -
				(withdrawableAmountAfterSixWeeks + withdrawableAmountAtTheEnd),
			votingPower
		);

		// withdrawable amount from dynamic stream
		withdrawableAmountAtTheEnd = i_sablierDynamic.withdrawableAmountOf(
			latestDynamicStreamId
		);
		i_sablierDynamic.withdraw(
			latestDynamicStreamId,
			testAddress,
			withdrawableAmountAtTheEnd
		);

		votingPower = sablierGovernor.getVotesWithParams(
			testAddress,
			block.number - 1,
			params
		);

		assertEq(testAddressBalance, votingPower);

		vm.stopPrank();
	}

	function test_getVotesWhenStreamIsCanceled()
		external
		createLinearStream
		createProposal
	{
		// createLinearStream creates stream with 1000 tokens inside of it
		// Additional 1000 tokens will be minted to the testAddress, which represents maxVotingPower of 2000 tokens
		uint256 maxVotingPower = 2000 * (10 ** DECIMALS); // i change nameOfThis

		// we mint additional 1000 tokens to the testAddress
		erc20Token.mint(testAddress, 1000 * (10 ** DECIMALS));
		uint256 testAddressBalance = erc20Token.balanceOf(testAddress);

		uint256 regularVotingPower = erc20Token.balanceOf(testAddress);
		vm.roll(block.number + 2);

		// voting power without streams
		uint256 votingPower = sablierGovernor.getVotes(
			testAddress,
			block.number - 1
		);
		assertEq(regularVotingPower, votingPower);

		// create params for getVotesWithParams
		uint256 proposalId = latestProposalId;
		SablierGovernor.StreamParams[]
			memory streamParams = new SablierGovernor.StreamParams[](1);
		streamParams[0] = SablierGovernor.StreamParams(
			latestLinearStreamId,
			SablierGovernor.StreamType.Linear
		);

		bytes memory params = abi.encode(streamParams, proposalId);

		votingPower = sablierGovernor.getVotesWithParams(
			testAddress,
			block.number - 1,
			params
		);

		assertEq(maxVotingPower, votingPower);

		vm.warp(block.timestamp + 6 weeks);
		vm.startPrank(testAddress);

		// withdrawable amount from linear stream
		uint128 withdrawableAmountAfterSixWeeks = i_sablierLinear
			.withdrawableAmountOf(latestLinearStreamId);

		i_sablierLinear.withdraw(
			latestLinearStreamId,
			testAddress,
			withdrawableAmountAfterSixWeeks
		);

		votingPower = sablierGovernor.getVotesWithParams(
			testAddress,
			block.number - 1,
			params
		);

		assertEq(maxVotingPower - withdrawableAmountAfterSixWeeks, votingPower);

		vm.stopPrank();

		// cancel the stream
		vm.prank(i_deployerAddress);
		i_sablierLinear.cancel(latestLinearStreamId);

		votingPower = sablierGovernor.getVotesWithParams(
			testAddress,
			block.number - 1,
			params
		);

		assertEq(testAddressBalance, votingPower);
	}
}
