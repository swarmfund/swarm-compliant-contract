const {BN, constants, expectEvent, shouldFail} = require('openzeppelin-test-helpers');
const crypto = require('crypto');
const moment = require('moment');
const helpers = require('./helpers');

const SRC20 = artifacts.require('SRC20Mock');
const FailedRestriction = artifacts.require('FailedRestrictionMock');
const SuccessfulRestriction = artifacts.require('SuccessfulRestrictionMock');
const TokenDataRestrictionMock = artifacts.require('TokenDataRestrictionMock');


contract('SRC20', async function ([_, manager, owner, authority0, authority1, account0, account1, delegate0]) {
  const kyaHash = crypto.createHash('sha256').update(constants.ZERO_ADDRESS).digest();
  const kyaUrl = 'https://www.mvpworkshop.co';
  const totalSupply = new BN(10000);
  const value = 100;
  const expDate = moment().unix() + (60 * 60 * 24);// one day from current time
  const accounts = helpers.accounts;
  const signTransfer = helpers.utils.signTransfer;
  const features = 0x00;

  beforeEach(async function () {
    this.failedRestriction = await FailedRestriction.new();
    this.successfulRestriction = await SuccessfulRestriction.new();
    this.tokenDataRestrictionMock = await TokenDataRestrictionMock.new();

    this.token = await SRC20.new(
      owner,
      'SRC20 token',
      'SRC',
      new BN(18),
      kyaHash,
      kyaUrl,
      constants.ZERO_ADDRESS,
      features,
      totalSupply,
      {from: manager}
    );
  });

  describe('Handling roles', function () {
    it('should allow owner to transfer ownership', async function () {
      ({logs: this.logs} = await this.token.transferOwnership(account0, {from: owner}));
      expectEvent.inLogs(this.logs, 'OwnershipTransferred', {
        previousOwner: owner,
        newOwner: account0
      });

      assert.equal(await this.token.owner() === account0, true);
    });

    it('should allow owner to add/remove and query delegates', async function () {
      ({logs: this.logs} = await this.token.addDelegate(delegate0, {from: owner}));
      expectEvent.inLogs(this.logs, 'DelegateAdded', {
        account: delegate0
      });

      assert.equal(await this.token.isDelegate(delegate0), true);

      ({logs: this.logs} = await this.token.removeDelegate(delegate0, {from: owner}));
      expectEvent.inLogs(this.logs, 'DelegateRemoved', {
        account: delegate0
      });

      assert.equal(await this.token.isDelegate(delegate0), false);
    });

    it('should allow authorities to be added and queried', async function () {
      await this.token.addAuthority(authority0, {from: owner});
      assert.equal(await this.token.isAuthority(authority0), true);
      assert.equal(await this.token.isAuthority(authority1), false);
    });

    it('should allow only owner to handle authorities', async function () {
      await this.token.addAuthority(authority0, {from: owner});
      await shouldFail.reverting(this.token.addAuthority(authority1, {from: authority0}));

      await this.token.addAuthority(authority1, {from: owner});
      await this.token.removeAuthority(authority1, {from: owner});
      await shouldFail.reverting(this.token.removeAuthority(authority0, {from: authority1}));
    });

    it('should fire events on adding and removing authority', async function () {
      ({logs: this.logs} = await this.token.addAuthority(authority0, {from: owner}));
      expectEvent.inLogs(this.logs, 'AuthorityAdded', {account: authority0});

      ({logs: this.logs} = await this.token.removeAuthority(authority0, {from: owner}));
      expectEvent.inLogs(this.logs, 'AuthorityRemoved', {account: authority0});
    });
  });

  describe('Handling KYA updates and delegates', function () {
    it('should change KYA data and return changed data to owner', async function () {
      ({logs: this.logs} = await this.token.updateKYA(kyaHash, kyaUrl, constants.ZERO_ADDRESS, {from: owner}));

      expectEvent.inLogs(this.logs, 'KYAUpdated', {
        kyaHash: helpers.utils.bufferToHex(kyaHash),
        kyaUrl: kyaUrl
      });

      const kya = await this.token.getKYA();
      assert.equal(kya[0], helpers.utils.bufferToHex(kyaHash));
      assert.equal(kya[1], kyaUrl);
    });

    it('should allow updating KYA to delegate', async function () {
      await this.token.addDelegate(delegate0, {from: owner});

      ({logs: this.logs} = await this.token.updateKYA(kyaHash, kyaUrl, constants.ZERO_ADDRESS, {from: delegate0}));

      expectEvent.inLogs(this.logs, 'KYAUpdated', {
        kyaHash: helpers.utils.bufferToHex(kyaHash),
        kyaUrl: kyaUrl
      });
    });

    it('should not allow updating KYA from public account', async function () {
      await shouldFail.reverting.withMessage(this.token.updateKYA(kyaHash, kyaUrl, constants.ZERO_ADDRESS, {from: delegate0}),
        "Not Owner or Delegate");
    });
  });

  describe('Handling transferToken with rules', async function () {
    it('should allow transfer with authorization signature from authority', async function () {
      await this.token.addAuthority(accounts.ACCOUNT0.address, {from: owner});

      const nonce = await this.token.getTransferNonce({from: owner});
      const {hash, signature} = signTransfer(kyaHash, owner, account0, value, nonce, expDate, accounts.ACCOUNT0.privateKey);

      ({logs: this.logs} = await this.token.transferToken(account0, value, nonce, expDate, hash, signature, {from: owner}));
      expectEvent.inLogs(this.logs, 'Transfer', {
        from: owner,
        to: account0,
        value: new BN(value)
      });
    });

    it('should not allow authorization signature from not authority account', async function () {
      await this.token.addAuthority(accounts.ACCOUNT0.address, {from: owner});

      const nonce = await this.token.getTransferNonce({from: owner});
      const {hash, signature} = signTransfer(kyaHash, owner, account0, value, nonce, expDate, accounts.ACCOUNT1.privateKey);

      await shouldFail.reverting.withMessage(this.token.transferToken(account0, value, nonce, expDate, hash, signature, {from: owner}),
        "transferToken params not authority");
    });

    it('should not allow signature for different account', async function () {
      await this.token.addAuthority(accounts.ACCOUNT0.address, {from: owner});

      const nonce = await this.token.getTransferNonce({from: owner});
      const {hash, signature} = signTransfer(kyaHash, owner, account0, value, nonce, expDate, accounts.ACCOUNT0.privateKey);

      await shouldFail.reverting.withMessage(this.token.transferToken(account1, value, nonce, expDate, hash, signature, {from: owner}),
        "transferToken params bad hash");
    });
  });

  describe('Burn and mint functionality', function () {
    it('should allow manager to mint token', async function () {
      ({logs: this.logs} = await this.token.mint(account0, value, {from: manager}));
      expectEvent.inLogs(this.logs, 'Transfer', {
        from: constants.ZERO_ADDRESS,
        to: account0,
        value: new BN(value)
      });
    });
    it('should allow manager to burn tokens', async function () {
      await this.token.mint(account0, value, {from: manager});

      ({logs: this.logs} = await this.token.burn(account0, value, {from: manager}));
      expectEvent.inLogs(this.logs, 'Transfer', {
        from: account0,
        to: constants.ZERO_ADDRESS,
        value: new BN(value)
      });
    });
    it('should not allow not manager accounts to burn tokens', async function () {
      await shouldFail.reverting.withMessage(this.token.burn(owner, value, {from: account0}),
        "Caller not manager");
    });
    it('should not allot not manager accounts to mint tokens', async function () {
      await shouldFail.reverting.withMessage(this.token.mint(account0, value, {from: account0}),
        "Caller not manager");
    });
  });

  describe('Allowances functionality', function () {
    it('should successfully approve and transferred all approved tokens', async function () {
      await this.token.approve(account0, value, {from: owner});

      await this.token.addAuthority(helpers.accounts.ACCOUNT0.address, {from: owner});

      const nonce = await this.token.getTransferNonce({from: owner});
      const {hash, signature} = helpers.utils.signTransfer(kyaHash, owner, account1, value, nonce, expDate, helpers.accounts.ACCOUNT0.privateKey);

      ({logs: this.logs} = await this.token.transferTokenFrom(owner, account1, value, nonce, expDate, hash, signature, {from: account0}));
      expectEvent.inLogs(this.logs, 'Transfer', {
        from: owner,
        to: account1,
        value: new BN(value)
      });
    });

    it('should allow spending approved tokens with multiple transfers', async function () {
      await this.token.approve(account0, value, {from: owner});

      await this.token.addAuthority(helpers.accounts.ACCOUNT0.address, {from: owner});

      let nonce = await this.token.getTransferNonce({from: owner});
      let {hash, signature} = helpers.utils.signTransfer(kyaHash, owner, account1, value / 2, nonce, expDate,
          helpers.accounts.ACCOUNT0.privateKey);

      await this.token.transferTokenFrom(owner, account1, value / 2, nonce, expDate, hash, signature, {from: account0});

      nonce = await this.token.getTransferNonce({from: owner});
      ({hash: hash, signature: signature} = helpers.utils.signTransfer(kyaHash, owner, account1, value / 2, nonce, expDate,
          helpers.accounts.ACCOUNT0.privateKey));

      ({logs: this.logs} = await this.token.transferTokenFrom(owner, account1, value / 2, nonce, expDate, hash, signature, {from: account0}));

      expectEvent.inLogs(this.logs, 'Transfer', {
        from: owner,
        to: account1,
        value: new BN(value).div(new BN(2)),
      });

      expectEvent.inLogs(this.logs, 'Approval', {
        owner: owner,
        spender: account0,
        value: new BN(0),
      });
    });

    it('should increase allowance increaseAllowance', async function () {
      await this.token.increaseAllowance(account0, value, {from: owner});

      await this.token.addAuthority(helpers.accounts.ACCOUNT0.address, {from: owner});

      const nonce = await this.token.getTransferNonce({from: owner});
      const {hash, signature} = helpers.utils.signTransfer(kyaHash, owner, account1, value, nonce, expDate, helpers.accounts.ACCOUNT0.privateKey);

      ({logs: this.logs} = await this.token.transferTokenFrom(owner, account1, value, nonce, expDate, hash, signature, {from: account0}));
      expectEvent.inLogs(this.logs, 'Transfer', {
        from: owner,
        to: account1,
        value: new BN(value)
      });
    });

    it('should decrease allowance with decreaseAllowance', async function () {
      await this.token.increaseAllowance(account0, value, {from: owner});
      await this.token.decreaseAllowance(account0, value, {from: owner});

      await this.token.addAuthority(helpers.accounts.ACCOUNT0.address, {from: owner});

      const nonce = await this.token.getTransferNonce({from: owner});
      const {hash, signature} = helpers.utils.signTransfer(kyaHash, owner, account1, 1, nonce, expDate, helpers.accounts.ACCOUNT0.privateKey);

      await shouldFail.reverting.withMessage(this.token.transferTokenFrom(owner, account1, 1, nonce, expDate, hash, signature, {from: account0}));
    });
  });

  describe('Configurable token features', function () {
    it('should allow forceTransfer with feature enabled', async function () {
      const forceTransfer = await this.token.ForceTransfer();

      await this.token.featureEnable(forceTransfer);
      ({logs: this.logs} = await this.token.transferTokenForced(owner, account0, value, {from: owner}));
      expectEvent.inLogs(this.logs, 'Transfer', {
        from: owner,
        to: account0,
        value: new BN(value)
      });
    });

    it('should not allow forceTransfer with feature disabled', async function () {
      await shouldFail.reverting.withMessage(this.token.transferTokenForced(owner, account0, value, {from: owner}),
        "Feature not enabled");
    });

    it('should allow token pausing if feature enabled', async function () {
      const tokenPausable = await this.token.Pausable();
      await this.token.featureEnable(tokenPausable);

      ({logs: this.logs} = await this.token.pauseToken({from: owner}));
      expectEvent.inLogs(this.logs, 'Paused');

      const isPaused = await this.token.paused({from: owner});
      assert.equal(isPaused, true);

    });

    it('should allow account freezing if feature enabled', async function () {
      const accountFreezing = await this.token.AccountFreezing();
      await this.token.featureEnable(accountFreezing);

      ({logs: this.logs} = await this.token.freezeAccount(account0, {from: owner}));
      expectEvent.inLogs(this.logs, 'AccountFrozen', {
        account: account0
      });

      const isAccountFrozen = await this.token.isAccountFrozen(account0, {from: owner});
      assert.equal(isAccountFrozen, true);

    });

    it('should not allow token pausing if caller is not owner');

    it('should not allow token pausing if feature disabled', async function () {
      await shouldFail.reverting.withMessage(this.token.pauseToken({from: owner}),
        "Feature not enabled");
    });

    it('should not allow account freezing if feature disabled', async function () {
      await shouldFail.reverting.withMessage(this.token.freezeAccount(account0, {from: owner}),
          "Feature not enabled");
    });



    it('should allow owner to burn tokens of any specific account, if feature enabled', async function () {
      const accountBurning = await this.token.AccountBurning();
      await this.token.featureEnable(accountBurning);

      ({logs: this.logs} = await this.token.burnAccount(owner, totalSupply, {from: owner}));
      expectEvent.inLogs(this.logs, 'Transfer', {
        from: owner,
        to: constants.ZERO_ADDRESS,
        value: new BN(totalSupply),
      });
      const supply = await this.token.totalSupply();
      assert.equal(supply.eq(new BN(0)), true);
    })
  });

  describe('Handling of on-chain transfer rules', function () {
    it('should allow transfer without on-chain restrictions', async function () {
      await this.token.addAuthority(helpers.accounts.ACCOUNT0.address, {from: owner});

      const nonce = await this.token.getTransferNonce({from: owner});
      const {hash, signature} = helpers.utils.signTransfer(kyaHash, owner, account0, value, nonce, expDate, helpers.accounts.ACCOUNT0.privateKey);

      ({logs: this.logs} = await this.token.transferToken(account0, value, nonce, expDate, hash, signature, {from: owner}));
      expectEvent.inLogs(this.logs, 'Transfer', {
        from: owner,
        to: account0,
        value: new BN(value)
      });
    });

    it('should allow transfer with successful on-chain restrictions', async function () {
      await this.token.updateKYA(kyaHash, kyaUrl, this.successfulRestriction.address, {from: owner});

      await this.token.addAuthority(helpers.accounts.ACCOUNT0.address, {from: owner});

      const nonce = await this.token.getTransferNonce({from: owner});
      const {hash, signature} = helpers.utils.signTransfer(kyaHash, owner, account0, value, nonce, expDate, helpers.accounts.ACCOUNT0.privateKey);

      ({logs: this.logs} = await this.token.transferToken(account0, value, nonce, expDate, hash, signature, {from: owner}));
      expectEvent.inLogs(this.logs, 'Transfer', {
        from: owner,
        to: account0,
        value: new BN(value)
      });
    });

    it('should not allow transfer with failed on-chain restrictions', async function () {
      await this.token.updateKYA(kyaHash, kyaUrl, this.failedRestriction.address, {from: owner});

      await this.token.addAuthority(helpers.accounts.ACCOUNT0.address, {from: owner});

      const nonce = await this.token.getTransferNonce({from: owner});
      const {hash, signature} = helpers.utils.signTransfer(kyaHash, owner, account0, value, nonce, expDate, helpers.accounts.ACCOUNT0.privateKey);

      await shouldFail.reverting.withMessage(this.token.transferToken(account0, value, nonce, expDate, hash, signature, {from: owner}),
        "transferToken restrictions failed");
    });

    it('should be able to present token data to on-chain rule contract', async function () {
      await this.token.updateKYA(kyaHash, kyaUrl, this.tokenDataRestrictionMock.address, {from: owner});

      await this.token.addAuthority(helpers.accounts.ACCOUNT0.address, {from: owner});

      const nonce0 = await this.token.getTransferNonce({from: owner});
      const {hash: hash0, signature: signature0} = helpers.utils.signTransfer(kyaHash, owner, account0, value, nonce0, expDate,
          helpers.accounts.ACCOUNT0.privateKey);

      ({logs: this.logs} = await this.token.transferToken(account0, value, nonce0, expDate, hash0, signature0, {from: owner}));
      expectEvent.inLogs(this.logs, 'Transfer', {
        from: owner,
        to: account0,
        value: new BN(value)
      });

      ({logs: this.logs} = await this.tokenDataRestrictionMock.emitTokenData());
      expectEvent.inLogs(this.logs, 'TokenData', {
        totalSupply: totalSupply,
        balance: new BN(totalSupply),
        nonce: new BN(0),
      });

      const nonce1 = await this.token.getTransferNonce({from: owner});
      const {hash: hash1, signature: signature1} = helpers.utils.signTransfer(kyaHash, owner, account0, value, nonce1, expDate,
          helpers.accounts.ACCOUNT0.privateKey);

      ({logs: this.logs} = await this.token.transferToken(account0, value, nonce1, expDate, hash1, signature1, {from: owner}));
      expectEvent.inLogs(this.logs, 'Transfer', {
        from: owner,
        to: account0,
        value: new BN(value)
      });

      ({logs: this.logs} = await this.tokenDataRestrictionMock.emitTokenData());
      expectEvent.inLogs(this.logs, 'TokenData', {
        totalSupply: totalSupply,
        balance: new BN(totalSupply).sub(new BN(value)),
        nonce: new BN(1),
      });
    });
  });
});
