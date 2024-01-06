### [M-1] Looping through players array to check for duplicates in `PuppyRaffle::enterRaffle` is a potential denial of service (DoS) attack, incrementing gas costs for future entrants.

**Description:** The `PuppyRaffle::enterRaffle` function loops through the `players` array to check for duplicate entries. However, the longer the `players` array is, the more checks a new player will have to make. This means the gas costs for players who enter right when the starts will be dramatically lower than those who enter later on. Every additional address in the `players` array is an additional check the loop will have to make.

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

### [M-2] `PuppyRaffle::getActivePlayerIndex` will return 0 for the first player which will make the first player assume they are not an active player.

**Description:** The `PuppyRaffle::getActivePlayerIndex` function loops through the `players` array to check for the players address and returns 0 if it's not found. However, it also returns the position of the array the player is found in. A player can be in `players[0]` position which will also return 0.

```javascript
        function getActivePlayerIndex(address player) external view returns (uint256) {
        for (uint256 i = 0; i < players.length; i++) {
            if (players[i] == player) {
>>              return i;
            }
        }
        return 0;
    }
```

**Impact:** The first player will assume they are not an active player in the raffle and will waste funds attempting to enter the raffle again. They will be rejected for being a duplicate entry by the `PuppyRaffle::enterRaffle` function which will waste gas costs for the user. This will also have a reputation hit as the user can share with others that the raffle is broken and to not interact with it.

**Proof of Concept:**

<details>
<summary> PoC </summary>

Place the following into your PuppyRaffleTest.t.sol

```javascript
    function test_getActivePlayersIndexReturnsZeroWhenPlayerIsInZeroPosition() public {
        address[] memory players = new address[](1);
        players[0] = address(1);
        puppyRaffle.enterRaffle{value: entranceFee}(players);
        assertEq(puppyRaffle.getActivePlayerIndex(address(1)), 0);
    }
```

</details>

**Recommended Mitigation:**

1. Consider verifying that the user is an active player before looking for the index. You can update `PuppyRaffle::_isActivePlayer` to accept an address then call it in `PuppyRaffle::getActivePlayerIndex` in a require statement to ensure the user exists. The require statement can throw an error to tell the player that there is no index for them as they are not an active participant.

<details>
<summary> Update _isActivePlayerIndex to this </summary>

Place the following into your PuppyRaffleTest.t.sol

```diff
    /// @notice this function will return true if the msg.sender is an active player
+   function _isActivePlayer(address player) internal view returns (bool) {
-   function _isActivePlayer() internal view returns (bool) {
        for (uint256 i = 0; i < players.length; i++) {
+           if (players[i] == player) {
-           if (players[i] == msg.sender) {
                return true;
            }
        }
        return false;
    }
```

</details>

<details>
<summary> Add require statement to getActivePlayerIndex </summary>

Place the following into your PuppyRaffleTest.t.sol

```diff
    function getActivePlayerIndex(address player) external view returns (uint256) {
+       require(_isActivePlayer(player), 'PuppyRaffle: Not active player')
        for (uint256 i = 0; i < players.length; i++) {
            if (players[i] == player) {
                return i;
            }
        }
-       return 0;
    }
```

</details>

### [H-1] Sending refund before updating players array in `PuppyRaffle::refund` allows for attacker to drain the protocol using a reentrancy attack.

**Description:** The `PuppyRaffle::refund` sends the refund to the msg.sender before assigning that index to the 0 address. If the receipient of the address is a contract which has a receive() method to call the function again with the same index, the `PuppyRaffle::refund` will evaluate the index again, see a valid `PuppyRaffle::playerAddress` and resend the refund.

```javascript
        function refund(uint256 playerIndex) public {
        address playerAddress = players[playerIndex];
        require(playerAddress == msg.sender, "PuppyRaffle: Only the player can refund");
        require(playerAddress != address(0), "PuppyRaffle: Player already refunded, or is not active");

>>      payable(msg.sender).sendValue(entranceFee);

        players[playerIndex] = address(0);
        emit RaffleRefunded(playerAddress);
    }
```

**Impact:** The attacker can steal all the funds in the protocol.

**Proof of Concept:**

If we enter 2 sets of a thousand players, the costs will be as following
Gas cost for entering the first 1000 players: 417422122
Gas cost for entering the second 1000 players: 1600800307

This is 3.8 times more cost.

<details>
<summary> PoC </summary>

Place the following into your PuppyRaffleTest.t.sol

```javascript

```

</details>

**Recommended Mitigation:**

1. Apply the Check-Effect-Interactions (CEI) design pattern by moving the transfer after updating the players array

<details>
<summary> Mitigation </summary>

```diff
    function refund(uint256 playerIndex) public {
        address playerAddress = players[playerIndex];
        require(playerAddress == msg.sender, "PuppyRaffle: Only the player can refund");
        require(playerAddress != address(0), "PuppyRaffle: Player already refunded, or is not active");

-       payable(msg.sender).sendValue(entranceFee);

        players[playerIndex] = address(0);
+       payable(msg.sender).sendValue(entranceFee);
        emit RaffleRefunded(playerAddress);
    }
```

</details>

2. Add a boolean variable that controls access to the refund function during a transaction

<details>
<summary> Mitigation </summary>

```diff
+   bool private locked = false;

    function refund(uint256 playerIndex) public {
+       require(locked == false, "PupprRaffle: Refund is locked");
+       locked = true;
        address playerAddress = players[playerIndex];
        require(playerAddress == msg.sender, "PuppyRaffle: Only the player can refund");
        require(playerAddress != address(0), "PuppyRaffle: Player already refunded, or is not active");

        payable(msg.sender).sendValue(entranceFee);

        players[playerIndex] = address(0);
        emit RaffleRefunded(playerAddress);
+       locked = false;
    }
```

</details>

3. Use the nonReentrant modifier in the ReentrancyGuard provided by the OpenZeppelins library.
