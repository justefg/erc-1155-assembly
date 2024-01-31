object "ERC1155Yul" {
    /*
    address owner; // slot 0

    string uri // slot 1 .. slot n

    mapping(uint256 => mapping(address => uint256)) private _balances;

    // Mapping from account to operator approvals
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    // Used as the URI for all token types by relying on ID substitution, e.g. https://token-cdn-domain/{id}.json
    string private _uri;
    */

    code {
        // Store the creator in slot zero.
        sstore(0, caller())

        // Deploy the contract
        datacopy(0, dataoffset("runtime"), datasize("runtime"))
        return(0, datasize("runtime"))
    }
    object "runtime" {
        code {
            require(iszero(callvalue()))

            switch selector()
            case 0x156e29f6 /* "mint(address,uint256,uint256)" */ {
                mint(decodeAsAddress(0), decodeAsUint(1), decodeAsUint(2))
                returnTrue()
            }
            case 0x00fdd58e /* "balanceOf(address,uint256)" */ {
                returnUint(balanceOf(decodeAsAddress(0), decodeAsUint(1)))
            }
            case 0xd81d0a15 /* mintBatch(address,uint256[],uint256[]) */ {
                mintBatch(decodeAsAddress(0), decodeAsUintArray(1), decodeAsUintArray(2))
            }
            case 0x4e1273f4 /* balanceOfBatch(address[],uint256[]) */ {
                balanceOfBatch(decodeAsAddressArray(0), decodeAsUintArray(1))
            }
            case 0x0febdd49 /* safeTransferFrom(address,address,uint256,uint256) */ {
                safeTransferFrom(decodeAsAddress(0), decodeAsAddress(1), decodeAsUint(2), decodeAsUint(3))
            }
            case 0xc9931e18 /* safeTransferFromBatch(address,address,uint256[],uint256[]) */ {
                safeTransferFromBatch(decodeAsAddress(0), decodeAsAddress(1), decodeAsUintArray(2), decodeAsUintArray(3))
            }
            case 0x02fe5305 /* setURI(string) */ {
                setURI(decodeAsUintArray(0))
            }
            case 0x7754305c /* getURI() */ {
                getURI()
            }
            case 0xa22cb465 /* setApprovalForAll(address,bool) */ {
                setApprovalForAll(caller(), decodeAsAddress(0), decodeAsUint(1))
            }
            case 0xe985e9c5 /* isApprovedForAll(address,address) */ {
                isApprovedForAll(decodeAsAddress(0), decodeAsAddress(1))
            }
            default {
                revert(0, 0)
            }

            function setApprovalForAll(account, operator, v) {
                require(iszero(eq(account, operator)))
                sstore(operatorToStorageOffset(account, operator), v)
                emitApproval(account, operator, v)
            }

            function isApprovedForAll(account, operator) {
                returnUint(sload(operatorToStorageOffset(account, operator)))
            }

            function setURI(u) {
                require(eq(owner(), caller()))
                let length := calldataload(u)
                // calculate words required to store a string
                // for example, one character string 'H' requires 1 words
                // cause it's represented as 'H' 000000000 (padded with zero bytes on the RIGHT)

                // save 0x0 memory for 0x20 offset as required by string abi encoding
                // 0x20 string length
                // 0x40 string start
                mstore(0x0, 0x20)
                calldatacopy(0x20, u, add(length, 0x20))
                let words := div(length, 0x20)
                if lt(mul(words, 0x20), length) {
                    words := add(words, 1)
                }
                // store length in slot 1
                sstore(0x20, length)
                for {
                    let i := 0
                } lt(i, words) {
                    i := add(i, 1)
                } {
                    sstore(add(0x40, mul(i, 0x20)), mload(add(0x40, mul(i, 0x20))))
                }
                // H000000
                //
                emitURI(add(0x40, mul(words, 0x20)))
            }

            function getURI() {
                mstore(0x0, 0x20)
                let length := sload(0x20)
                let words := div(length, 0x20)
                if lt(mul(words, 0x20), length) {
                    words := add(words, 1)
                }
                mstore(0x20, length)
                for {
                    let i := 0
                } lt(i, words) {
                    i := add(i, 1)
                } {
                    mstore(
                        add(0x40, mul(i, 0x20)),
                        sload(add(0x40, mul(i, 0x20)))
                    )
                }
                return(0x00, add(0x40, mul(0x20, length)))
            }

            function safeTransferFrom(from, to, id, amount) {
                require(eq(from, caller()))
                let fromBalancePtr := accountToStorageOffset(from, id)
                let fromBalance := sload(fromBalancePtr)
                require(iszero(lt(fromBalance, amount)))
                sstore(fromBalancePtr, sub(fromBalance, amount))
                let toBalancePtr := accountToStorageOffset(to, id)
                let toBalance := sload(toBalancePtr)
                sstore(toBalancePtr, add(toBalance, amount))
                emitTransfer(from, from, to, id, amount)
            }

            function safeTransferFromBatch(from, to, idsPtr, amountsPtr) {
                let length := calldataload(idsPtr)
                require(eq(length, calldataload(amountsPtr)))
                idsPtr := add(0x20, idsPtr)
                amountsPtr := add(0x20, amountsPtr)
                for {
                    let i := 0
                } lt(i, length) {
                    i := add(i, 1)
                } {
                    safeTransferFrom(
                        from,
                        to,
                        calldataload(add(idsPtr, mul(i, 0x20))),
                        calldataload(add(amountsPtr, mul(i, 0x20)))
                    )
                }
                emitTransferBatch(from, from, to, idsPtr, amountsPtr, length)
            }

            function mint(account, id, amount) {
                require(calledByOwner())
                sstore(accountToStorageOffset(account, id), amount)
                emitTransfer(owner(), 0x0, account, id, amount)
            }

            function balanceOfBatch(addressPtr, idsPtr) {
                let length := calldataload(addressPtr)
                require(eq(length, calldataload(idsPtr)))
                addressPtr := add(0x20, addressPtr)
                idsPtr := add(0x20, idsPtr)
                let freeMemPtr := 0x40
                mstore(freeMemPtr, 0x20) // offset in a resulting array
                mstore(add(freeMemPtr, 0x20), length)
                let array_start := add(freeMemPtr, 0x40)

                for {
                    let i := 0
                } lt(i, length) {
                    i := add(i, 1)
                } {
                    mstore(
                        add(array_start, mul(i, 0x20)),
                        balanceOf(
                            calldataload(add(addressPtr, mul(i, 0x20))),
                            calldataload(add(idsPtr, mul(i, 0x20)))
                        )
                    )
                }
                return(freeMemPtr, add(0x40, mul(0x20, length)))
            }

            function mintBatch(account, idsPtr, amountPtr) {
                let length := calldataload(idsPtr)
                require(eq(length, calldataload(amountPtr)))
                idsPtr := add(0x20, idsPtr)
                amountPtr := add(0x20, amountPtr)
                for {
                    let i := 0
                } lt(i, length) {
                    i := add(i, 1)
                } {
                    mint(
                        account,
                        calldataload(add(idsPtr, mul(0x20, i))),
                        calldataload(add(amountPtr, mul(0x20, i)))
                    )
                }
                emitTransferBatch(owner(), 0x0, account, idsPtr, amountPtr, length)
            }

            /* ---------- calldata decoding functions ----------- */
            function selector() -> s {
                s := div(calldataload(0), 0x100000000000000000000000000000000000000000000000000000000)
            }

            function decodeAsAddress(offset) -> v {
                v := decodeAsUint(offset)
                if iszero(iszero(and(v, not(0xffffffffffffffffffffffffffffffffffffffff)))) {
                    revert(0, 0)
                }
            }

            function decodeAsUint(offset) -> v {
                let pos := add(4, mul(offset, 0x20))
                if lt(calldatasize(), add(pos, 0x20)) {
                    revert(0, 0)
                }
                v := calldataload(pos)
            }

            function decodeAsUintArray(offset) -> v {
                let pos := add(4, mul(offset, 0x20))
                // assert calldatasize
                v := add(4, calldataload(pos))
            }

            function decodeAsAddressArray(offset) -> v {
                let pos := add(4, mul(offset, 0x20))
                // assert calldatasize
                v := add(4, calldataload(pos))
            }

            /* ---------- calldata encoding functions ---------- */
            function returnUint(v) {
                mstore(0, v)
                return(0, 0x20)
            }
            function returnTrue() {
                returnUint(1)
            }
            function packUintArray(dest, arrayStart, length) -> o {
                mstore(dest, length)
                calldatacopy(add(dest, 0x20), arrayStart, mul(length, 0x20))
                o := add(dest, mul(add(1, length), 0x20))
            }
            /* -------- events ---------- */
            function emitTransfer(operator, from, to, nonIndexedId, nonIndexedAmount) {
                let signatureHash := 0xc3d58168c5ae7397731d063d5bbf3d657854427343f4c083240f7aacaa2d0f62
                mstore(0, nonIndexedId)
                mstore(0x20, nonIndexedAmount)
                log4(0, 0x40, signatureHash, operator, from, to)
            }
            function emitTransferBatch(operator, from, to, ids, amounts, length) {
                let signatureHash := 0x4a39dc06d4c0dbc64b70af90fd698a233a518aa5d07e595d983b8c0526c8f7fb
                // |  0x0  |    0x20        |   0x40      |   0x60  |   .... |  idsOffset + idsLength * 0x20 |
                //  idsOffset  amountsOffset   idsLength   ids(0)         ..............................        amountsLength
                mstore(0, 0x40)
                let amountOffset := packUintArray(0x40, ids, length)
                mstore(0x20, amountOffset)
                let bytesWritten := packUintArray(amountOffset, amounts, length)
                log4(0x0, bytesWritten, signatureHash, operator, from, to)
            }
            function emitURI(bytesToEmit) {
                let signatureHash := 0x3d7a9962f6da134f6896430d6867bd08e3546dbf9570df877e7cec39ba4305f0 // URI(string)
                log1(0, bytesToEmit, signatureHash)
            }
            function emitApproval(account, operator, v) {
                let signatureHash := 0x17307eab39ab6107e8899845ad3d59bd9653f200f220920489ca2b5937696c31 // ApprovalForAll(address,address,bool)
                mstore(0x0, v)
                log3(0, 0x20, signatureHash, account, operator)
            }

            /* -------- storage layout ---------- */
            function ownerPos() -> p {
                p := 0
            }
            function uriPos() -> p {
                p := 1
            }
            function accountToStorageOffset(account, id) -> o {
                // o := keccak(keccak(random_slot, id), account)
                mstore(0x0, 1000) // just a slot random number
                mstore(0x20, id)
                let innerHash := keccak256(0, 0x40)
                mstore(0x0, innerHash)
                mstore(0x20, account)
                o := keccak256(0, 0x40)
            }

            function operatorToStorageOffset(account, operator) -> o {
                mstore(0x0, 0x2000)
                mstore(0x20, account)
                let innerHash := keccak256(0x0, 0x40)
                mstore(0x0, innerHash)
                mstore(0x20, operator)
                o := keccak256(0x0, 0x40)
            }
            /* -------- storage access ---------- */
            function owner() -> o {
                o := sload(ownerPos())
            }
            function uri() -> u {
                u := sload(uriPos())
            }
            function balanceOf(account, id) -> bal {
                bal := sload(accountToStorageOffset(account, id))
            }
            /* ---------- utility functions ---------- */
            function lte(a, b) -> r {
                r := iszero(gt(a, b))
            }
            function gte(a, b) -> r {
                r := iszero(lt(a, b))
            }
            function safeAdd(a, b) -> r {
                r := add(a, b)
                if or(lt(r, a), lt(r, b)) { revert(0, 0) }
            }
            function calledByOwner() -> cbo {
                cbo := eq(owner(), caller())
            }
            function revertIfZeroAddress(addr) {
                require(addr)
            }
            function require(condition) {
                if iszero(condition) { revert(0, 0) }
            }
        }
    }
}
