### [M-1] Looping through players area to check for duplicates in `PuppyRaffle::enterRaffle` is a potential denial of service (DoS) attack, incrementing gas costs for future entrants.

**Description:** The `PuppyRaffle::enterRaffle` function loops through the `players` array to check for duplicate entried. However, the longer the `players` array is, the more checks a new player will have to make. This means the gas costs for players who enter right when the starts will be dramatically lower than those who enter later on. Every additional address in the `players` array is an additional check the loop will have to make.

```javascript
        // Check for duplicates
>>      for (uint256 i = 0; i < players.length - 1; i++) {
            for (uint256 j = i + 1; j < players.length; j++) {
                require(players[i] != players[j], "PuppyRaffle: Duplicate player");
            }
        }
```

**Impact:** The gas cost for entrants will greatly increase as more players enter the raffle. Discouraing later users from entering and causing a rush at the start of the raffle. An attacker might make the array so big that no else can feasibly enter, guarenteeing the win for themselves.

**Proof of Concept:**

If we enter 2 sets of a thousand players, the costs will be as following
Gas cost for entering the first 1000 players: 417422122
Gas cost for entering the second 1000 players: 1600800307

This is 3.8 times more cost.

<details>
<summary> PoC </summary>

Place the following into your PuppyRaffleTest.t.sol

```javascript
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
```

</details>

**Recommended Mitigation:**

1. Consider allow duplicates. A user can generate new addresses with little so a duplicate check will not prevent the same person entering multiple times. Only a single wallet.
2. Consider using a mapping to check for duplicates. This would allow constant time lookup of whether a user has already entered.
3. Use OpenZeppelins EnumurableSet library.
