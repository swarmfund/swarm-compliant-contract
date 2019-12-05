const {BN, constants, expectEvent, shouldFail} = require('openzeppelin-test-helpers');
const crypto = require('crypto');
const moment = require('moment');
const helpers = require('../token/helpers');
const {encodeTransfer} = require('../token/utils');

const SwarmPoweredFundraiseMock = artifacts.require('SwarmPoweredFundraiseMock');
const SwarmPoweredFundraiseFinished = artifacts.require('SwarmPoweredFundraiseFinished');
const SwarmPoweredFundraiseCanceled = artifacts.require('SwarmPoweredFundraiseCanceled');
const SwarmPoweredFundraiseExpired = artifacts.require('SwarmPoweredFundraiseExpired');
const Erc20Token = artifacts.require('SwarmTokenMock');
const Utils = artifacts.require('Utils');
const CurrencyRegistry = artifacts.require('CurrencyRegistry');
const ContributorRestrictions = artifacts.require('ContributorRestrictions');
const ContributionRules = artifacts.require('ContributionRules');
const AffiliateManager = artifacts.require('AffiliateManager');
const UniswapProxy = artifacts.require('UniswapProxy');
const UniswapMock = artifacts.require('UniswapMock');
const maxContributors = 100;

contract('SwarmPoweredFundraise', async function ([_, whitelistManager /*authority*/, owner, issuer, contributor]) {
  const ercTotalSupply = new BN(123456789);
  const amount = new BN(198);
  const minAmountBCY = new BN(9);
  const maxAmountBCY = new BN(999);

  const label = 'TestFundraise';
  const src20 = helpers.accounts.ACCOUNT0.address;
  //const currencyRegistry = helpers.accounts.ACCOUNT1.address;
  const SRC20tokenSupply = 10000;
  const startDate = moment().unix(); // current time
  const endDate = moment().unix() + (60 * 60 * 72); // three days from current time;
  const softCapBCY = 1111;
  const hardCapBCY = 5555;

  beforeEach(async function () {

    // Currency stuff
    this.daiExchange = await UniswapMock.new({from: owner});
    await this.daiExchange.setTokenToETHRate(1, {from: owner});
    this.uniswapProxy = await UniswapProxy.new({from: owner});
    await this.uniswapProxy.addOrUpdateExchange(
      "0x89d24A6b4CcB1B6fAA2625fE562bDD9a23260359", // DAI
      this.daiExchange.address,
      {from: owner}
    );
    this.currencyRegistry = await CurrencyRegistry.new({from: owner});
    await this.currencyRegistry.addCurrency(
      constants.ZERO_ADDRESS,
      this.uniswapProxy.address,
      {from: owner}
    );
    await this.currencyRegistry.addCurrency(
      "0x89d24A6b4CcB1B6fAA2625fE562bDD9a23260359",
      this.uniswapProxy.address,
      {from: owner}
    );

    // //console.log('UniswapProxy:', this.uniswapProxy.address);
    // //console.log('XXX:', await this.currencyRegistry.currenciesList.call(0));
    // //console.log('YYY:', await this.currencyRegistry.currencyIndex.call(constants.ZERO_ADDRESS));
    // //console.log('ZZZ:', await this.currencyRegistry.getAcceptedCurrencies());
    // //console.log('XXX:', await this.currencyRegistry.currencyIndex.call("0x89d24A6b4CcB1B6fAA2625fE562bDD9a23260359"));
    // //console.log('UniswapProxy:', this.uniswapProxy);
    // let aa = await this.currencyRegistry.toBCY.call(1,constants.ZERO_ADDRESS);
    // //console.log('toBCY:', aa.toString());

    // ETH
    await this.currencyRegistry.setBaseCurrency(constants.ZERO_ADDRESS, {from: owner});
    // this.erc20DAI = await Erc20Token.new(owner, ercTotalSupply, {from: owner});
    // this.erc20DAI.address = "0x89d24A6b4CcB1B6fAA2625fE562bDD9a23260359";
    this.notAcceptedToken = await Erc20Token.new(owner, ercTotalSupply, {from: owner});

    // Setup for new accepted token... needs its own exchange too
    this.acceptedToken = await Erc20Token.new(owner, ercTotalSupply, {from: owner});
    this.acceptedTokenExchange = await UniswapMock.new({from: owner});
    await this.acceptedTokenExchange.setTokenToETHRate(1, {from: owner});
    await this.uniswapProxy.addOrUpdateExchange(
      this.acceptedToken.address,
      this.acceptedTokenExchange.address,
      {from: owner}
    );
    await this.currencyRegistry.addCurrency(
      this.acceptedToken.address,
      this.uniswapProxy.address,
      {from: owner}
    );

    // so that contributor can contribute...
    await this.acceptedToken.transfer(contributor, amount, {from: owner});

    this.affiliateManager = await AffiliateManager.new({from: owner});

    const utilsLib = await Utils.new();
    await SwarmPoweredFundraiseMock.link(Utils, utilsLib.address);

    this.swarmPoweredFundraiseMock = await SwarmPoweredFundraiseMock.new(
      label,
      src20,
      this.currencyRegistry.address,
      SRC20tokenSupply,
      startDate,
      endDate,
      softCapBCY,
      hardCapBCY,
      {from: owner}
    );

    this.contributorRestrictions = await ContributorRestrictions.new(
      this.swarmPoweredFundraiseMock.address,
      maxContributors,
      {from: owner}
    );

    this.contributionRules = await ContributionRules.new(
      minAmountBCY,
      maxAmountBCY,
      {from: owner}
    );

    await this.swarmPoweredFundraiseMock.setupContract(
      minAmountBCY,
      maxAmountBCY,
      this.affiliateManager.address,
      this.contributorRestrictions.address,
      this.contributionRules.address,
      {from: owner}
    );

    this.contributorRestrictions.whitelistAccount(contributor, {from: owner});

    // @TODO change owner to be token issuer...

    await SwarmPoweredFundraiseFinished.link(Utils, utilsLib.address);
    this.swarmPoweredFundraiseFinished = await SwarmPoweredFundraiseFinished.new(
      label,
      src20,
      this.currencyRegistry.address,
      SRC20tokenSupply,
      startDate,
      endDate,
      softCapBCY,
      hardCapBCY,
      {from: owner}
    );
    //this.swarmPoweredFundraiseCanceled = await SwarmPoweredFundraiseCanceled.new({from: owner});
    //this.swarmPoweredFundraiseExpired = await SwarmPoweredFundraiseExpired.new({from: owner});

    // @TODO increase total sum per contributor checks
    // @TODO decrease total sum per contributor check
  });

  describe('Handling incoming contributions', function () {

    it('should allow anyone to contribute ETH to the contract', async function () {
      // check the current state of the contract
      let beforeBalance = await this.swarmPoweredFundraiseMock.getBalanceETH(contributor);

      // contribute funds
      await this.swarmPoweredFundraiseMock.send(amount, {from: contributor});

      // check that the funds are added to the contributions of the msg.sender
      let afterBalance = await this.swarmPoweredFundraiseMock.getBalanceETH(contributor);
      let actualBalance = await web3.eth.getBalance(this.swarmPoweredFundraiseMock.address);

      //console.log('afterBalance:', afterBalance.toString());
      //console.log('actualBalance:', actualBalance.toString());

      let bb = await this.swarmPoweredFundraiseMock.getQualifiedContributions(contributor, constants.ZERO_ADDRESS);
      //console.log('getQualifiedContributions:', bb.toString());
      bb = await this.swarmPoweredFundraiseMock.getBufferedContributions(contributor, constants.ZERO_ADDRESS);
      //console.log('getBufferedContributions:', bb.toString());

      assert.equal(beforeBalance.add(amount).eq(afterBalance), true);
    });

    it('should allow anyone to contribute accepted currency (ERC20 token) to the contract', async function () {
      // check the current state of the contract
      const beforeBalance = await this.swarmPoweredFundraiseMock.getBalanceToken(contributor, this.acceptedToken.address);

      // contribute
      await this.acceptedToken.transfer(contributor, amount, {from: owner});
      await this.acceptedToken.approve(this.swarmPoweredFundraiseMock.address, amount, {from: contributor});
      await this.swarmPoweredFundraiseMock.contribute(this.acceptedToken.address, amount, "", {from: contributor});

      // check that the funds are added to the contributions of the msg.sender
      const afterBalance = await this.swarmPoweredFundraiseMock.getBalanceToken(contributor, this.acceptedToken.address);

      assert.equal(beforeBalance.add(amount).eq(afterBalance), true);
    });

    it('should not allow anyone to contribute not-acceptable currency (ERC20 token) to the contract', async function () {
      // contribute
      await shouldFail.reverting.withMessage(
         this.swarmPoweredFundraiseMock.contribute(this.notAcceptedToken.address, amount, "", {from: owner}),
        'Unsupported contribution currency'
      );
    });

  });

  describe('Handling contribution limits', function () {
    it('should fail to qualify ETH if it does not satisfy contribution rules - min amount', async function () {

      // Whiteliste the contributor first
      // this.contributorRestrictions.whitelistAccount(contributor, {from: owner});

      // check the current state of the contract
      let beforeBalance = await this.swarmPoweredFundraiseMock.getQualifiedContributions(contributor, constants.ZERO_ADDRESS);
      //console.log('beforeBalance:', beforeBalance);

      let lessThanMinAmount = minAmountBCY - 1;
      // contribute funds
      await this.swarmPoweredFundraiseMock.send(lessThanMinAmount, {from: contributor});

      let afterBalance = await this.swarmPoweredFundraiseMock.getQualifiedContributions(contributor, constants.ZERO_ADDRESS);
      //console.log('afterBalance:', afterBalance.toString());

      // check that the funds are added to the contributions of the msg.sender
      // let contractETHBalance = await web3.eth.getBalance(this.swarmPoweredFundraiseMock.address);
      // //console.log('contractETHBalance:', contractETHBalance);

      assert.equal(beforeBalance.eq(afterBalance), true);
    });

    it('should fail to qualify ERC20 if it does not satisfy contribution rules - min amount in ERC20', async function () {
      await this.acceptedToken.approve(this.swarmPoweredFundraiseMock.address, amount, {from: contributor});
      
      let lessThanMinAmount = minAmountBCY - 1;

      let beforeBalance = await this.swarmPoweredFundraiseMock.getQualifiedContributions(contributor, this.acceptedToken.address);
      //console.log('getQualifiedContributions before:', beforeBalance.toString());

      await this.swarmPoweredFundraiseMock.contribute(this.acceptedToken.address, lessThanMinAmount, '', {from: contributor});

      let afterBalance = await this.swarmPoweredFundraiseMock.getQualifiedContributions(contributor, this.acceptedToken.address);
      //console.log('getQualifiedContributions after:', afterBalance.toString());

      assert.equal(beforeBalance.eq(afterBalance), true);
    });

    it('should fail if it does not satisfy contribution rules - max contributors', async function () {
      await this.swarmPoweredFundraiseMock.setNumContributorsToMax();
      await this.acceptedToken.approve(this.swarmPoweredFundraiseMock.address, amount, {from: contributor});
      ////console.log('numberOfContributors: ', await this.swarmPoweredFundraiseMock.numberOfContributors.call().toString());
      await shouldFail.reverting.withMessage(
          this.swarmPoweredFundraiseMock.contribute(this.acceptedToken.address, amount, '', {from: contributor}),
          'Max number of contributors exceeded!'
      );
    });

    it('should reject ETH contributions after the fundraising has finished', async function () {
      await shouldFail.reverting.withMessage(
          this.swarmPoweredFundraiseFinished.send(amount, {from: whitelistManager}),
          'Only owner can send ETH if fundraise has finished!');
    });

    it('should reject token contributions after the fundraising has finished', async function () {
      await shouldFail.reverting.withMessage(
        this.swarmPoweredFundraiseFinished.contribute(this.acceptedToken.address, amount, '', {from: contributor}),
        'Fundraise has finished!'); // Fundraise has finished!
    });

    it('should reject ETH contributions after the fundraising has been cancelled', async function () {
      // cancel the fundraise
      await this.swarmPoweredFundraiseMock.cancelFundraise({from: owner});
      await shouldFail.reverting.withMessage(
        this.swarmPoweredFundraiseMock.send(amount, {from: contributor}),
        'Only owner can send ETH if fundraise has finished!'
      );

      // // send funds to canceled fundraising contract
      // await shouldFail.reverting.withMessage(this.swarmPoweredFundraiseCanceled.send(amount, {from:owner}),
      //     'Contribution has been rejected: fundraising is canceled');
    });

    it('should reject contribution if ERC20 token is not accepted', async function () {
      // contribute
      await this.acceptedToken.approve(this.swarmPoweredFundraiseMock.address, amount, {from: contributor});
      await shouldFail.reverting.withMessage(
        this.swarmPoweredFundraiseMock.contribute(this.notAcceptedToken.address, amount, '', {from: contributor}),
          'Unsupported contribution currency');
    });
  });
/*
  describe('Handling withdrawals of the contributions', function () { // @TODO move to new file
    it('should allow contributor to withdraw his investments in ETH if fundraising is finished', async function () {
      const beforeBalance = await this.swarmPoweredFundraiseMock.getBalanceETH(contributor);

      await this.swarmPoweredFundraiseMock.send(amount, {from:owner});
      await this.swarmPoweredFundraiseMock.finishFundraising({from: owner});

      await this.swarmPoweredFundraiseMock.withdrawInvestmentETH({from: owner});
      const afterBalance = await this.swarmPoweredFundraiseMock.getBalanceETH(contributor);

      assert.equal(afterBalance === beforeBalance, true);
    });

    it('should allow contributor to withdraw his investments in ERC20 token if fundraising is finished', async function () {
      const beforeBalance = await this.swarmPoweredFundraiseMock.getBalanceToken(this.acceptedToken.address, contributor);

      await this.acceptedToken.approve(this.swarmPoweredFundraiseMock.address, amount, {from: owner});
      await this.swarmPoweredFundraiseMock.contribute(this.acceptedToken.address, amount, {from: owner});
      await this.swarmPoweredFundraiseMock.finishFundraising({from: owner});

      await this.swarmPoweredFundraiseMock.withdrawInvestmentToken({from: owner});
      const afterBalance = await this.swarmPoweredFundraiseMock.getBalanceToken(contributor);

      assert.equal(afterBalance === beforeBalance, true);
    });

    it('should not allow contributor to withdraw his contribution in ETH if fundraising is not finished', async function () {
      await this.swarmPoweredFundraiseMock.send(amount, {from: owner});

      await shouldFail.reverting.withMessage(this.swarmPoweredFundraiseMock.withdrawInvestmentETH({from: owner}),
          'Contribution withdrawal has been rejected: Fundraising not finished');
    });

    it('should not allow contributor to withdraw his contribution in ERC20 if fundraising is not finished', async function () {
      await this.acceptedToken.approve(this.swarmPoweredFundraiseMock.address, amount, {from: owner});
      await this.swarmPoweredFundraiseMock.contribute['contribute(address,uint256)']
      (this.acceptedToken.address, amount, {from: owner});

      await shouldFail.reverting.withMessage(this.swarmPoweredFundraiseMock.withdrawInvestmentToken({from: owner}),
          'Contribution withdrawal has been rejected: Fundraising not finished');
    });


  });
  */


});
