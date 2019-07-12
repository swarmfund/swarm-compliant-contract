const abi = require('ethereumjs-abi');

module.exports = {
    signTransfer,
    bufferToHex,
    calcTokens
};

function signTransfer(kyaHash, owner, account0, value, nonce, expDate, privateKey) {
    const hash = '0x' + abi.soliditySHA3(
        ["bytes32", "address", "address", "uint256", "uint256", "uint256"],
        [kyaHash, owner, account0, value, nonce, expDate]
    ).toString('hex');

    const {message, messageHash, v, r, s, signature} = web3.eth.accounts.sign(hash, privateKey);

    return {
        expiration: expDate,
        hash: hash,
        msgHash: messageHash,
        v, r, s, signature
    };
}

function calcTokens(srcValue, swmValue, swmValueStake) {
    return swmValueStake.mul(srcValue).div(swmValue);
}

function bufferToHex(buffer) {
    return '0x' + buffer.toString('hex');
}
