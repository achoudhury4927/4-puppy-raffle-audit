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

### [I-1] raffleDuration can be set to immutable to save on gas costs

**Description:** The raffleDuration variable is set once in the constructor and never updated. It would be more gas efficient to set it as immutable, as during contract creation it will replace any location with raffleDuration with the value itself. This will reduce the number of times storage will need to be called.

**Impact:** Gas

**Proof of Concept:** N/A

**Recommended Mitigation:**

```diff
+   uint256 public immutable raffleDuration;
-   uint256 public raffleDuration;
```

### [I-2] Storage decentralisation of NFT can be improved

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

### [I-3] ImageURI variables can be set to constant to save on gas costs

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
