// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";

contract RaffleTest is Test {
    /* Events */
    event Raffle__EnteredRaffle(address indexed player);

    /* State Variables */
    Raffle raffle;
    HelperConfig helperConfig;

    uint256 entranceFee;
    uint256 lotteryInterval;
    address vrfCoordinator;
    bytes32 vrfGasLaneKeyHash;
    uint64 subscriptionId;
    uint32 callbackGasLimit;
    address linkToken;
    uint256 deployerKey;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    modifier skipFork() {
        if (block.chainid != 31337) {
            return;
        }
        _;
    }

    modifier raffleEntered() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        _;
    }

    modifier timePassed() {
        vm.warp(block.timestamp + lotteryInterval + 1);
        vm.roll(block.number + 1);
        _;
    }

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.run();
        (
            entranceFee,
            lotteryInterval,
            vrfCoordinator,
            vrfGasLaneKeyHash,
            subscriptionId,
            callbackGasLimit,
            linkToken,
            deployerKey
        ) = helperConfig.activeNetworkConfig();

        vm.deal(PLAYER, STARTING_USER_BALANCE);
    }

    function test_RaffleInitialisesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    /** enterRaffle **/
    function test_RaffleRevertsWhenYouDoNotPayEnough() public {
        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle__NotEnoughEth.selector);
        raffle.enterRaffle();
    }

    function test_CannotEnterWhenRaffleIsCalculating()
        public
        raffleEntered
        timePassed
    {
        raffle.performUpkeep("");

        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        raffle.enterRaffle{value: entranceFee}();
    }

    function test_RaffleRecordsPlayerWhenTheyEnter() public raffleEntered {
        address playerRecorded = raffle.getPlayer(0);
        assert(playerRecorded == address(PLAYER));
    }

    function test_EmitsEventOnEntrance() public {
        vm.prank(PLAYER);
        vm.expectEmit(true, false, false, false, address(raffle));
        emit Raffle__EnteredRaffle(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    /** checkUpkeep **/
    function test_CheckUpkeepReturnsFalseIfItHasNoBalance() public timePassed {
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        assert(!upkeepNeeded);
    }

    function test_CheckUpkeepReturnsFalseIfNotEnoughTimeHasPassed() public {
        vm.roll(block.number + 1);
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        assert(!upkeepNeeded);
    }

    function test_CheckUpkeepReturnsTrueWhenParametersAreGood()
        public
        raffleEntered
        timePassed
    {
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        assert(upkeepNeeded);
    }

    function test_CheckUpkeepReturnsFalseIfRaffleIsNotOpen()
        public
        raffleEntered
        timePassed
    {
        raffle.performUpkeep("");
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        assert(!upkeepNeeded);
    }

    /** performUpkeep **/
    function test_PerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue()
        public
        raffleEntered
        timePassed
    {
        raffle.performUpkeep("");
    }

    function test_PerformUpkeepRevertsIfUpkeepNotNeeded() public {
        uint256 numberOfPlayers = 0;
        uint256 raffleState = 0;
        vm.prank(PLAYER);
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpkeepNotNeeded.selector,
                address(raffle).balance,
                numberOfPlayers,
                raffleState
            )
        );

        raffle.performUpkeep("");
    }

    function test_PerformUpkeepUpdatesRaffleState()
        public
        raffleEntered
        timePassed
    {
        raffle.performUpkeep("");
        Raffle.RaffleState raffleState = raffle.getRaffleState();

        assert(uint256(raffleState) == 1);
    }

    function test_PerformUpkeepEmitsRequestId()
        public
        raffleEntered
        timePassed
    {
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory logEntries = vm.getRecordedLogs();
        bytes32 requestId = logEntries[1].topics[1];

        assert(uint256(requestId) > 0);
    }

    /** fulfillRandomWords **/
    function test_FulFillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(
        uint256 randomRequestId
    ) public skipFork raffleEntered timePassed {
        vm.expectRevert("nonexistent request");
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            randomRequestId,
            address(raffle)
        );
    }

    function test_FulfillRandomWordsPicksAWinnerResetsAndSendsMoney()
        public
        skipFork
        raffleEntered
        timePassed
    {
        uint256 additionalEntrants = 5;
        uint256 startingIndex = 1;

        for (
            uint256 i = startingIndex;
            i < startingIndex + additionalEntrants;
            i++
        ) {
            address player = address(uint160(i));
            hoax(player, STARTING_USER_BALANCE);
            raffle.enterRaffle{value: entranceFee}();
        }

        uint256 prize = entranceFee * (additionalEntrants + 1);

        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory logEntries = vm.getRecordedLogs();
        bytes32 requestId = logEntries[1].topics[1];
        uint256 previousTimestamp = raffle.getLastTimestamp();

        vm.recordLogs();
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );
        logEntries = vm.getRecordedLogs();

        address winner = raffle.getRecentWinner();

        assert(winner != address(0));
        assert(uint256(raffle.getRaffleState()) == 0);
        assert(raffle.getPlayersLength() == 0);
        assert(previousTimestamp < raffle.getLastTimestamp());
        assertEq(
            logEntries[0].topics[0],
            keccak256("Raffle__PickedWinner(address)")
        );
        assert(winner.balance == STARTING_USER_BALANCE - entranceFee + prize);
    }
}
