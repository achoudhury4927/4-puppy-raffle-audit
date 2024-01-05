### [F-1] '^' allows versions >0.7.6 to compile which can lead to unintended functionality. It also older than the current latest version of solidity.

**Description:** Use of the ^ allows versions later than 0.7.6. There may be bugs introduced in the future versions that will allow exploitation in unintended ways.

**Impact:** Low - It will also inherit bug fixes that are discovered.

**Proof of Concept:** N/A

**Recommended Mitigation:** Remove '^' version range character and stick to 0.7.6 explicitly. Even better would be update to the latest version of 0.8.18 (as of writing).

```diff
+   pragma solidity 0.7.6;
-   pragma solidity ^0.7.6;
```

Or

```diff
+   pragma solidity 0.8.18;
-   pragma solidity ^0.7.6;
```

### [F-2] raffleDuration can be set to immutable to save on gas costs

**Description:** The raffleDuration variable is set once in the constructor and never updated. It would be more gas efficient to set it as immutable, as during contract creation it will replace any location with raffleDuration with the value itself. This will reduce the number of times storage will need to be called.

**Impact:** Gas

**Proof of Concept:** N/A

**Recommended Mitigation:**

```diff
+   uint256 public immutable raffleDuration;
-   uint256 public raffleDuration;
```

### [F-3] Storage decentralisation of NFT can be improved

**Description:** IPFS is more decentralised than hosting on a cloud database but there is a slight chance the data can be lost if nobody hosts a node with the image downloaded. Decentralisation can be improved by storing an svg of the image onchain for the imageURI variables

**Impact:** Information

**Proof of Concept:** N/A

**Recommended Mitigation:** Remove '^' version range character and stick to 0.7.6 explicitly. Even better would be update to the latest version of 0.8.18 (as of writing).

```diff
+   string private legendaryImageUri;
+   string private rareImageUri;
+   string private commonImageUri;
-   string private legendaryImageUri = "ipfs://QmYx6GsYAKnNzZ9A6NvEKV9nf1VaDzJrqDR23Y8YSkebLU";
-   string private rareImageUri = "ipfs://QmUPjADFGEKmfohdTaNcWhp7VGk26h5jXDA7v3VtTnTLcW";
-   string private commonImageUri = "ipfs://QmSsYRx3LpDAb1GZQm7zZ1AuHZjfbPkD6J7s9r41xu1mf8";

```

Add all three variables to the constructor and provide the svg is base64 format using foundry in the deploy script

```diff
+    string public LEGENDARY_IMAGE_URI_FROM_FILE = vm.readFile("./img/base64_legendary_image_uri.svg.txt");

+    PuppyRaffle puppyRaffle = new PuppyRaffle(entraceFee, feeAddress, raffleDuration, LEGENDARY_IMAGE_URI_FROM_FILE)
```

Repeat above for common and rare

### [F-4] ImageURI variables can be set to constant to save on gas costs

**Description:** The ImageURI variables is never updated. It would be more gas efficient to set it as constant, as during contract creation it will replace any location with the ImageURI's with the value itself. This will reduce the number of times storage will need to be called.

**Impact:** Gas

**Proof of Concept:** N/A

**Recommended Mitigation:**

```diff
+   string private constant legendaryImageUri = "ipfs://QmYx6GsYAKnNzZ9A6NvEKV9nf1VaDzJrqDR23Y8YSkebLU";
+   string private constant rareImageUri = "ipfs://QmUPjADFGEKmfohdTaNcWhp7VGk26h5jXDA7v3VtTnTLcW";
+   string private constant commonImageUri = "ipfs://QmSsYRx3LpDAb1GZQm7zZ1AuHZjfbPkD6J7s9r41xu1mf8";
-   string private legendaryImageUri = "ipfs://QmYx6GsYAKnNzZ9A6NvEKV9nf1VaDzJrqDR23Y8YSkebLU";
-   string private rareImageUri = "ipfs://QmUPjADFGEKmfohdTaNcWhp7VGk26h5jXDA7v3VtTnTLcW";
-   string private commonImageUri = "ipfs://QmSsYRx3LpDAb1GZQm7zZ1AuHZjfbPkD6J7s9r41xu1mf8";

```

### [F-5] Should check for Zero Address provided on \_feeAddress

### [F-6] Informational: Should be called participants according to doc

### [F-7] Medium: DDOS with a massive length or a small length if the players list is huge already

### [F-8] Informational-Gas: Use cached length

### [F-9] HIGH: Reentrancy, value is sent before players array is updated to remove the player. If player is a contract address refund can be recalled by a fallback or receive function.

### [F-9] Low: User cannot differentiate being an active player in the 0th position and user not found

### [F-10] HIGH: Attacker can maniupulate block.timestamp to select the winner.

After the change to POS block.difficulty is unused so has been set to a constant of 0. This is because it irrelevant to proof of stake.

This means that the only source if "randomness" in this calculation is block.timestamp which can be gamed by the attacker in advance.

The attacker can calculate the winnerIndexe outside of this transaction ahead of time to ensure the winner is who they select.

### [F-11] HIGH: Refund only zeroes out the index of a player before returning their entrance fee.

Players.length will include refunded players so totalAmountCollected will be the wrong amount.

So will prizepool which will drain the protocol of its fees to be collected/fail to transfer to the winner due to insufficient balance

### [F-12] HIGH: This does not provide RNG. Each msg.sender will have one rarity calculated for them which can never change.

### [F-13] HIGH: tokenId is not incremented thus this mint will fail after the first winner is selected as that nft will already have an owner

### [F-14] High: An attacker can DDOS all fee withdrawls by selfdestructing a contract to send wei to this contract. This will make the require statement fail.

### [F-15] High: Anyone can call the withdrawFees method

Questionable
Informational-Gas: Use mapping so no need to loop through array
Can fee be larger than uint64
Why arent we using sendValue here? Is there any exploits with call vs sendValue
Is there a scenario where we want fees to be burnt by assigning zero address
Can Zero Address call this function?
