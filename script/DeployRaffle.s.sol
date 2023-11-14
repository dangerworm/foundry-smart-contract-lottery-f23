// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployRaffle is Script {
    function run() external returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        (
            uint256 entranceFee,
            uint256 lotteryInterval,
            address vrfCoordinator,
            bytes32 vrfGasLaneKeyHash,
            uint64 subscriptionId,
            uint32 callbackGasLimit
        ) = helperConfig.activeNetworkConfig();

        vm.startBroadcast();
        Raffle raffle = new Raffle({
            entranceFee: entranceFee,
            lotteryInterval: lotteryInterval,
            vrfCoordinator: vrfCoordinator,
            vrfGasLaneKeyHash: vrfGasLaneKeyHash,
            subscriptionId: subscriptionId,
            callbackGasLimit: callbackGasLimit
        });
        vm.stopBroadcast();

        return (raffle, helperConfig);
    }
}
