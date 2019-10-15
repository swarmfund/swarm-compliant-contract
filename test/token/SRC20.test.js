const {BN, constants, expectEvent, shouldFail} = require('openzeppelin-test-helpers');
const crypto = require('crypto');
const moment = require('moment');
const helpers = require('./helpers');
const {encodeTransfer} = require('./utils');

const SRC20Registry = artifacts.require('SRC20RegistryMock');
const SRC20Factory = artifacts.require('SRC20Factory');
const SRC20 = artifacts.require('SRC20Mock');
const SwarmTokenMock = artifacts.require('SwarmTokenMock');
const FailedRestriction = artifacts.require('FailedRestrictionMock');
const SuccessfulRestriction = artifacts.require('SuccessfulRestrictionMock');
const TokenDataRestrictionMock = artifacts.require('TokenDataRestrictionMock');
const SRC20Roles = artifacts.require('SRC20Roles');
const TransferRules = artifacts.require('TransferRules');
const FeaturedMock = artifacts.require('FeaturedMock');
const AssetRegistry = artifacts.require('AssetRegistry');

contract('SRC20', async function ([_, manager, owner, authority0, authority1, account0, account1, delegate0]) {
  const kyaHash = crypto.createHash('sha256').update(constants.ZERO_ADDRESS).digest();
  const kyaUrl = 'https://www.mvpworkshop.co';
  const SRC20_DECIMALS = new BN(18);
  const totalSupply = new BN(10000000).mul(new BN(10).pow(SRC20_DECIMALS));
  const maxTokenSupply = new BN(10000000000000).mul(new BN(10).pow(SRC20_DECIMALS));
  const value = 100;
  const expDate = moment().unix() + (60 * 60 * 24);// one day from current time
  const accounts = helpers.accounts;
  const signTransfer = helpers.utils.signTransfer;
  const features = 0x00;

  beforeEach(async function () {
    this.swarmTokenMock = await SwarmTokenMock.new(account0, totalSupply, {from: owner});
    this.registry = await SRC20Registry.new(this.swarmTokenMock.address, {from: owner});
    this.factory = await SRC20Factory.new(this.registry.address, {from: owner});
    await this.registry.addFactory(this.factory.address, {from: owner});

    this.failedRestriction = await FailedRestriction.new(owner);
    this.successfulRestriction = await SuccessfulRestriction.new(owner);
    this.tokenDataRestrictionMock = await TokenDataRestrictionMock.new(owner);

    this.tokenTransferRules = await TransferRules.new(owner, {from: owner});

    this.featured = await FeaturedMock.new(owner, features, {from: owner});

    this.roles = await SRC20Roles.new(owner, manager, this.tokenTransferRules.address, {from: owner});

    this.assetRegistry = await AssetRegistry.new(this.factory.address, {from: owner});

    this.token = await SRC20.new(
        'SRC20 token',
        'SRC',
        SRC20_DECIMALS,
        maxTokenSupply,
        [
            owner,
            constants.ZERO_ADDRESS,
            constants.ZERO_ADDRESS,
            this.roles.address,
            this.featured.address,
            this.assetRegistry.address
        ],
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
      ({logs: this.logs} = await this.roles.addDelegate(delegate0, {from: owner}));
      expectEvent.inLogs(this.logs, 'DelegateAdded', {
        account: delegate0
      });

      assert.equal(await this.roles.isDelegate(delegate0), true);

      ({logs: this.logs} = await this.roles.removeDelegate(delegate0, {from: owner}));
      expectEvent.inLogs(this.logs, 'DelegateRemoved', {
        account: delegate0
      });

      assert.equal(await this.roles.isDelegate(delegate0), false);
    });

    it('should allow authorities to be added and queried', async function () {
      await this.roles.addAuthority(authority0, {from: owner});
      assert.equal(await this.roles.isAuthority(authority0), true);
      assert.equal(await this.roles.isAuthority(authority1), false);
    });

    it('should allow only owner to handle authorities', async function () {
      await this.roles.addAuthority(authority0, {from: owner});
      await shouldFail.reverting(this.roles.addAuthority(authority1, {from: authority0}));

      await this.roles.addAuthority(authority1, {from: owner});
      await this.roles.removeAuthority(authority1, {from: owner});
      await shouldFail.reverting(this.roles.removeAuthority(authority0, {from: authority1}));
    });

    it('should fire events on adding and removing authority', async function () {
      ({logs: this.logs} = await this.roles.addAuthority(authority0, {from: owner}));
      expectEvent.inLogs(this.logs, 'AuthorityAdded', {account: authority0});

      ({logs: this.logs} = await this.roles.removeAuthority(authority0, {from: owner}));
      expectEvent.inLogs(this.logs, 'AuthorityRemoved', {account: authority0});
    });
  });

  describe('Handling KYA updates and delegates', function () {
    it('should change KYA data and return changed data to owner', async function () {
      await this.roles.addDelegate(delegate0, {from: owner});
      ({logs: this.logs} = await this.assetRegistry.updateKYA(this.token.address, kyaHash, kyaUrl, {from: delegate0}));

      expectEvent.inLogs(this.logs, 'AssetKYAUpdated', {
        src20: this.token.address,
        kyaHash: helpers.utils.bufferToHex(kyaHash),
        kyaUrl: kyaUrl
      });

      const kya = await this.assetRegistry.getKYA(this.token.address);
      assert.equal(kya[0], helpers.utils.bufferToHex(kyaHash));
      assert.equal(kya[1], kyaUrl);
    });

    it('should allow updating KYA to delegate', async function () {
      await this.roles.addDelegate(delegate0, {from: owner});
      ({logs: this.logs} = await this.assetRegistry.updateKYA(this.token.address, kyaHash, kyaUrl, {from: delegate0}));

      expectEvent.inLogs(this.logs, 'AssetKYAUpdated', {
        src20: this.token.address,
        kyaHash: helpers.utils.bufferToHex(kyaHash),
        kyaUrl: kyaUrl
      });
    });

    it('should not allow updating KYA from public account', async function () {
      await shouldFail.reverting.withMessage(this.assetRegistry.updateKYA(this.token.address, kyaHash, kyaUrl, {from: delegate0}),
        "Caller not delegate");
    });
  });

  describe('Handling transferToken with rules', async function () {
    it('should allow transfer with authorization signature from authority', async function () {
      await this.roles.addDelegate(delegate0, {from: owner});
      ({logs: this.logs} = await this.assetRegistry.updateKYA(this.token.address, kyaHash, kyaUrl, {from: delegate0}));

      await this.roles.addAuthority(accounts.ACCOUNT0.address, {from: owner});

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
      await this.roles.addDelegate(delegate0, {from: owner});
      ({logs: this.logs} = await this.assetRegistry.updateKYA(this.token.address, kyaHash, kyaUrl, {from: delegate0}));

      await this.roles.addAuthority(accounts.ACCOUNT0.address, {from: owner});

      const nonce = await this.token.getTransferNonce({from: owner});
      const {hash, signature} = signTransfer(kyaHash, owner, account0, value, nonce, expDate, accounts.ACCOUNT1.privateKey);

      await shouldFail.reverting.withMessage(this.token.transferToken(account0, value, nonce, expDate, hash, signature, {from: owner}),
        "transferToken params not authority");
    });

    it('should not allow signature for different account', async function () {
      await this.roles.addAuthority(accounts.ACCOUNT0.address, {from: owner});

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
      await this.roles.addDelegate(delegate0, {from: owner});
      ({logs: this.logs} = await this.assetRegistry.updateKYA(this.token.address, kyaHash, kyaUrl, {from: delegate0}));

      await this.token.approve(account0, value, {from: owner});

      await this.roles.addAuthority(helpers.accounts.ACCOUNT0.address, {from: owner});

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
      await this.roles.addDelegate(delegate0, {from: owner});
      ({logs: this.logs} = await this.assetRegistry.updateKYA(this.token.address, kyaHash, kyaUrl, {from: delegate0}));

      await this.token.approve(account0, value, {from: owner});

      await this.roles.addAuthority(helpers.accounts.ACCOUNT0.address, {from: owner});

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
      await this.roles.addDelegate(delegate0, {from: owner});
      ({logs: this.logs} = await this.assetRegistry.updateKYA(this.token.address, kyaHash, kyaUrl, {from: delegate0}));

      await this.token.increaseAllowance(account0, value, {from: owner});

      await this.roles.addAuthority(helpers.accounts.ACCOUNT0.address, {from: owner});

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

      await this.roles.addAuthority(helpers.accounts.ACCOUNT0.address, {from: owner});

      const nonce = await this.token.getTransferNonce({from: owner});
      const {hash, signature} = helpers.utils.signTransfer(kyaHash, owner, account1, 1, nonce, expDate, helpers.accounts.ACCOUNT0.privateKey);

      await shouldFail.reverting.withMessage(this.token.transferTokenFrom(owner, account1, 1, nonce, expDate, hash, signature, {from: account0}));
    });
  });

  describe('Configurable token features', function () {
    it('should allow forceTransfer with feature enabled', async function () {
      const forceTransfer = await this.featured.ForceTransfer();

      await this.featured.featureEnable(forceTransfer);
      ({logs: this.logs} = await this.token.transferTokenForced(owner, account0, value, {from: owner}));
      expectEvent.inLogs(this.logs, 'Transfer', {
        from: owner,
        to: account0,
        value: new BN(value)
      });
    });

    it('should not allow forceTransfer with feature disabled', async function () {
      await shouldFail.reverting.withMessage(this.token.transferTokenForced(owner, account0, value, {from: owner}),
        "Token feature is not enabled");
    });

    it('should allow token pausing if feature enabled', async function () {
      const tokenPausable = await this.featured.Pausable();
      await this.featured.featureEnable(tokenPausable);

      ({logs: this.logs} = await this.featured.pauseToken({from: owner}));
      expectEvent.inLogs(this.logs, 'Paused');

      const isPaused = await this.featured.paused({from: owner});
      assert.equal(isPaused, true);

    });

    it('should allow account freezing if feature enabled', async function () {
      const accountFreezing = await this.featured.AccountFreezing();
      await this.featured.featureEnable(accountFreezing);

      ({logs: this.logs} = await this.featured.freezeAccount(account0, {from: owner}));
      expectEvent.inLogs(this.logs, 'AccountFrozen', {
        account: account0
      });

      const isAccountFrozen = await this.featured.isAccountFrozen(account0, {from: owner});
      assert.equal(isAccountFrozen, true);
    });

    it('should not allow token pausing if caller is not owner', async function () {
      const pausable = await this.featured.Pausable();
      await this.featured.featureEnable(pausable);

      await shouldFail.reverting.withMessage(this.featured.pauseToken({from: account1}),
          "Ownable: caller is not the owner");
    });

    it('should not allow token pausing if feature disabled', async function () {
      await shouldFail.reverting.withMessage(this.featured.pauseToken({from: owner}),
        "Token feature is not enabled");
    });

    it('should not allow account freezing if feature disabled', async function () {
      await shouldFail.reverting.withMessage(this.featured.freezeAccount(account0, {from: owner}),
          "Token feature is not enabled");
    });



    it('should allow owner to burn tokens of any specific account, if feature enabled', async function () {
      const accountBurning = await this.featured.AccountBurning();
      await this.featured.featureEnable(accountBurning);

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
      await this.roles.addDelegate(delegate0, {from: owner});
      ({logs: this.logs} = await this.assetRegistry.updateKYA(this.token.address, kyaHash, kyaUrl, {from: delegate0}));

      await this.roles.addAuthority(helpers.accounts.ACCOUNT0.address, {from: owner});

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
      await this.roles.addDelegate(delegate0, {from: owner});
      await this.assetRegistry.updateKYA(this.token.address, kyaHash, kyaUrl, {from: delegate0});
      await this.token.updateRestrictionsAndRules(this.successfulRestriction.address, this.successfulRestriction.address, {from: delegate0});

      await this.roles.addAuthority(helpers.accounts.ACCOUNT0.address, {from: owner});

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
      await this.roles.addDelegate(delegate0, {from: owner});
      await this.assetRegistry.updateKYA(this.token.address, kyaHash, kyaUrl, {from: delegate0});
      await this.token.updateRestrictionsAndRules(this.failedRestriction.address, this.failedRestriction.address, {from: delegate0});

      await this.roles.addAuthority(helpers.accounts.ACCOUNT0.address, {from: owner});

      const nonce = await this.token.getTransferNonce({from: owner});
      const {hash, signature} = helpers.utils.signTransfer(kyaHash, owner, account0, value, nonce, expDate, helpers.accounts.ACCOUNT0.privateKey);

      await shouldFail.reverting.withMessage(this.token.transferToken(account0, value, nonce, expDate, hash, signature, {from: owner}),
        "transferToken restrictions failed");
    });

    it('should be able to present token data to on-chain rule contract', async function () {
      await this.roles.addDelegate(delegate0, {from: owner});
      await this.assetRegistry.updateKYA(this.token.address, kyaHash, kyaUrl, {from: delegate0});
      await this.token.updateRestrictionsAndRules(this.tokenDataRestrictionMock.address, this.tokenDataRestrictionMock.address, {from: delegate0});

      await this.roles.addAuthority(helpers.accounts.ACCOUNT0.address, {from: owner});

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

  describe('handling transfer rules', function () {
    it('should be able to whitelist account', async function () {
      await this.roles.addDelegate(delegate0, {from: owner});
      await this.assetRegistry.updateKYA(this.token.address, kyaHash, kyaUrl, {from: delegate0});
      await this.token.updateRestrictionsAndRules(this.tokenTransferRules.address, this.tokenTransferRules.address, {from: delegate0});

      await this.tokenTransferRules.whitelistAccount(account0, {from: owner});

      assert.equal(await this.tokenTransferRules.isWhitelisted(account0), true);
    });

    it('should be able to grey list account', async function () {
      await this.roles.addDelegate(delegate0, {from: owner});
      await this.assetRegistry.updateKYA(this.token.address, kyaHash, kyaUrl, {from: delegate0});
      await this.token.updateRestrictionsAndRules(this.tokenTransferRules.address, this.tokenTransferRules.address, {from: delegate0});

      await this.tokenTransferRules.greyListAccount(account0, {from: owner});

      assert.equal(await this.tokenTransferRules.isGreyListed(account0), true);
    });

    it('should be able to bulk whitelist account', async function () {
      await this.roles.addDelegate(delegate0, {from: owner});
      await this.assetRegistry.updateKYA(this.token.address, kyaHash, kyaUrl, {from: delegate0});
      await this.token.updateRestrictionsAndRules(this.tokenTransferRules.address, this.tokenTransferRules.address, {from: delegate0});

      await this.tokenTransferRules.bulkWhitelistAccount([account0, account1], {from: owner});

      assert.equal(await this.tokenTransferRules.isWhitelisted(account0), true);
      assert.equal(await this.tokenTransferRules.isWhitelisted(account1), true);
    });

    it('should be able to bulk grey list account', async function () {
      await this.roles.addDelegate(delegate0, {from: owner});
      await this.assetRegistry.updateKYA(this.token.address, kyaHash, kyaUrl, {from: delegate0});
      await this.token.updateRestrictionsAndRules(this.tokenTransferRules.address, this.tokenTransferRules.address, {from: delegate0});

      await this.tokenTransferRules.bulkGreyListAccount([account0,account1], {from: owner});

      assert.equal(await this.tokenTransferRules.isGreyListed(account0), true);
      assert.equal(await this.tokenTransferRules.isGreyListed(account1), true);
    });

    it('should be able to transfer when from is owner and to is whitelisted account', async function () {

    });

    it('should be able to transfer when from and to are whitelisted address', async function () {
      await this.roles.addDelegate(delegate0, {from: owner});
      await this.assetRegistry.updateKYA(this.token.address, kyaHash, kyaUrl, {from: delegate0});
      await this.token.updateRestrictionsAndRules(this.tokenTransferRules.address, this.tokenTransferRules.address, {from: delegate0});

      await this.tokenTransferRules.whitelistAccount(owner, {from: owner});
      await this.tokenTransferRules.whitelistAccount(account0, {from: owner});

      ({logs: this.logs} = await this.token.transfer(account0, value, {from: owner}));
      expectEvent.inLogs(this.logs, 'Transfer', {
        from: owner,
        to: account0,
        value: new BN(value)
      });

      const balanceOwner = await this.token.balanceOf(owner);
      const balanceAccount0 = await this.token.balanceOf(account0);

      assert.equal(totalSupply.sub(new BN(value)).eq(balanceOwner), true);
      assert.equal(new BN(value).eq(balanceAccount0), true)
    });

    it('should not be able to transfer when from or to are not whitelisted address', async function () {
      await this.roles.addDelegate(delegate0, {from: owner});
      await this.assetRegistry.updateKYA(this.token.address, kyaHash, kyaUrl, {from: delegate0});
      await this.token.updateRestrictionsAndRules(this.tokenTransferRules.address, this.tokenTransferRules.address, {from: delegate0});

      await this.tokenTransferRules.whitelistAccount(owner, {from: owner});

      await shouldFail.reverting.withMessage(this.token.transfer(account0, value, {from: owner}), 'Transfer not authorized');
    });

    it('should be able to request transfer of funds when from or to are greylisted', async function () {
      await this.roles.addDelegate(delegate0, {from: owner});
      await this.assetRegistry.updateKYA(this.token.address, kyaHash, kyaUrl, {from: delegate0});
      await this.token.updateRestrictionsAndRules(this.tokenTransferRules.address, this.tokenTransferRules.address, {from: delegate0});

      await this.tokenTransferRules.whitelistAccount(owner, {from: owner});
      await this.tokenTransferRules.greyListAccount(account0, {from: owner});

      ({logs: this.logs} = await this.token.transfer(account0, value, {from: owner}));
      expectEvent.inLogs(this.logs, 'Transfer', {
        from: owner,
        to: this.tokenTransferRules.address,
        value: new BN(value)
      });

      const balanceOwner = await this.token.balanceOf(owner);
      const balanceRulesContract = await this.token.balanceOf(this.tokenTransferRules.address);
      const balanceAccount0 = await this.token.balanceOf(account0);

      assert.equal(totalSupply.sub(new BN(value)).eq(balanceOwner), true);
      assert.equal(new BN(value).eq(balanceRulesContract), true);
      assert.equal(new BN(0).eq(balanceAccount0), true);

    });

    it('should be able to execute transfer request when from or to are greylisted', async function () {
      await this.roles.addDelegate(delegate0, {from: owner});
      await this.assetRegistry.updateKYA(this.token.address, kyaHash, kyaUrl, {from: delegate0});
      await this.token.updateRestrictionsAndRules(this.tokenTransferRules.address, this.tokenTransferRules.address, {from: delegate0});

      await this.tokenTransferRules.whitelistAccount(owner, {from: owner});
      await this.tokenTransferRules.greyListAccount(account0, {from: owner});

      await this.token.transfer(account0, value, {from: owner});

      const reqNumber = await this.tokenTransferRules._reqNumber();
      await this.tokenTransferRules.transferApproval(reqNumber.sub(new BN(1)), {from: owner});

      const balanceOwner = await this.token.balanceOf(owner);
      const balanceRulesContract = await this.token.balanceOf(this.tokenTransferRules.address);
      const balanceAccount0 = await this.token.balanceOf(account0);

      assert.equal(totalSupply.sub(new BN(value)).eq(balanceOwner), true);
      assert.equal(new BN(0).eq(balanceRulesContract), true);
      assert.equal(new BN(value).eq(balanceAccount0), true);
    });

    it('should be able to cancel transfer request as a owner', async function () {
      await this.roles.addDelegate(delegate0, {from: owner});
      await this.assetRegistry.updateKYA(this.token.address, kyaHash, kyaUrl, {from: delegate0});
      await this.token.updateRestrictionsAndRules(this.tokenTransferRules.address, this.tokenTransferRules.address, {from: delegate0});

      await this.tokenTransferRules.whitelistAccount(owner, {from: owner});
      await this.tokenTransferRules.greyListAccount(account0, {from: owner});

      await this.token.transfer(account0, value, {from: owner});
      const reqNumber = await this.tokenTransferRules._reqNumber();
      await this.tokenTransferRules.cancelTransferRequest(reqNumber.sub(new BN(1)), {from: owner});

      const balanceOwner = await this.token.balanceOf(owner);
      const balanceRulesContract = await this.token.balanceOf(this.tokenTransferRules.address);
      const balanceAccount0 = await this.token.balanceOf(account0);

      assert.equal(totalSupply.eq(balanceOwner), true);
      assert.equal(new BN(0).eq(balanceRulesContract), true);
      assert.equal(new BN(0).eq(balanceAccount0), true);
    })
  });

  describe('distribution functionality', function () {
    it('a delegate should be able to distribute tokens using bulkTransfer()', async function () {
      await this.roles.addDelegate(delegate0, {from: owner});
      await this.token.approve(delegate0, value, {from: owner});

      const addresses = [account0];
      const values = [value.toString()];

      ({logs: this.logs} = await this.token.bulkTransfer(addresses, values, {from: delegate0}));
      const balance = await this.token.balanceOf(account0);

      assert.equal(value, balance);
    });

    it('a delegate should be able to distribute tokens using encodedBulkTransfer()', async function () {
      await this.roles.addDelegate(delegate0, {from: owner});
      await this.token.approve(delegate0, value, {from: owner});

      const batches = [{
        address: account0,
        amount: value.toString()
      }];

      const transfers = batches.map(encodeTransfer);

      ({logs: this.logs} = await this.token.encodedBulkTransfer(1, transfers, {from: delegate0}));
      const balance = await this.token.balanceOf(account0);

      assert.equal(value, balance);
    });

    it('should not allow anyone but a delegate to distribute tokens using bulkTransfer()', async function () {

      await this.roles.addDelegate(delegate0, {from: owner});
      await this.token.approve(delegate0, value, {from: owner});
      await this.roles.removeDelegate(delegate0, {from: owner});

      const addresses = [account0];
      const values = [value.toString()];

      await shouldFail.reverting.withMessage(this.token.bulkTransfer(addresses, values, {from: delegate0}),
      "Caller not delegate" );
    });

    it('should not allow anyone but a delegate to distribute tokens using encodedBulkTransfer()', async function () {
      await this.roles.addDelegate(delegate0, {from: owner});
      await this.token.approve(delegate0, value, {from: owner});
      await this.roles.removeDelegate(delegate0, {from: owner});

      const batches = [{
        address: account0,
        amount: value.toString()
      }];

      const transfers = batches.map(encodeTransfer);

      await shouldFail.reverting.withMessage(this.token.encodedBulkTransfer(1, transfers, {from: delegate0}),
      "Caller not delegate" );
    });
  });
});
