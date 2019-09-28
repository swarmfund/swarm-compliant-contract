'use strict';

function encodeTransfer ({address, amount}) {
  return web3.utils.toHex(amount) + address.slice(2);
}

module.exports = {
  encodeTransfer
};