const {BN, constants, expectEvent, shouldFail} = require('openzeppelin-test-helpers');
const crypto = require('crypto');
const moment = require('moment');
const helpers = require('../token/helpers');
const {encodeTransfer} = require('../token/utils');

const SwarmTokenMock = artifacts.require('SwarmTokenMock');
const SWMPriceOracle = artifacts.require('SWMPriceOracle');
const SRC20Registry = artifacts.require('SRC20RegistryMock');

const SwarmPoweredFundraiseMock = artifacts.require('SwarmPoweredFundraiseMock');
const IssuerStakeOfferPool = artifacts.require('IssuerStakeOfferPool');

const Erc20Token = artifacts.require('SwarmTokenMock');

contract('Third party actions', async function ([_, src20, owner, issuer, contributor, account0]) {
    const label = "mvpworkshop.co";
    const tokenAmount = new BN(1000);
    const startDate = new BN(moment().unix());
    const endDate = new BN(moment().unix() + 100);
    const softCap = new BN(100);
    const hardCap = new BN(1000);
    const SWM_PRICE_USD_NUMERATOR = 5;
    const SWM_PRICE_USD_DENOMINATOR = 100;

    const ercTotalSupply = new BN(10000);

    const amount = new BN(10);

    const swmAmount = new BN(11);
    const minAmountNeeded = new BN(10);
    const maxMarkupPrice = new BN(100);

    const markup = new BN(50);

    beforeEach(async function () {
        this.swarmTokenMock = await SwarmTokenMock.new(account0, ercTotalSupply, {from: owner});
        this.registry = await SRC20Registry.new(this.swarmTokenMock.address, {from: owner});

        // @TODO uniswap token price oracle or mock price oracle
        this.SWMPriceOracle = await SWMPriceOracle.new(SWM_PRICE_USD_NUMERATOR, SWM_PRICE_USD_DENOMINATOR, {from: owner});

        this.swarmPoweredFundraiseMock = await SwarmPoweredFundraiseMock.new(
            label,
            src20,
            tokenAmount,
            startDate,
            endDate,
            softCap,
            hardCap,
            constants.ZERO_ADDRESS,
            {from: issuer});

        await this.swarmPoweredFundraiseMock.send(amount, {from: owner})
    });

    describe('Issuer stake offer pool', () => {
        it('', async function () {
            // should be able to set up ISOP as a swarm
            // SRC20Registry
            // min amount of swarms needed
            // max markup price

            // should allow any wallet to register as stake offerer
            // min amount swarms needed
            // max price markup
            // should transfer swarms to ISOP

            // isop should be able to take funds from fundraising
            // isop should be able to buy swarms from stake offer...??>?>??
            // isop should be able to stake & mint tokens

            // should allow only ISOP to take funds from fundraising, buys swarms and stake-mint tokens
        });

        it('should be able to setup ISOP as a swarm', async function () {
            this.ISOP = await IssuerStakeOfferPool.new(this.registry.address, minAmountNeeded, maxMarkupPrice, {from: owner});

            const actualRegistry = await this.ISOP.src20Registry();
            const actualMinAmount = await this.ISOP.minAmountNeeded();
            const actualMaxMarkupPrice = await this.ISOP.maxMarkup();

            assert.equal(actualRegistry === this.registry.address, true);
            assert.equal(actualMinAmount.eq(minAmountNeeded), true);
            assert.equal(actualMaxMarkupPrice.eq(maxMarkupPrice), true);
        });

        it('should allow any wallet to register to a stake offer pool if desirable condition are meat.', async function () {
            // deploy ISOP
            this.ISOP = await IssuerStakeOfferPool.new(this.registry.address, minAmountNeeded, maxMarkupPrice, {from: owner});

            // register wallet
            await this.swarmTokenMock.approve(this.ISOP.address, swmAmount, {from: account0});
            await this.ISOP.register(swmAmount, markup, {from: account0});

            // check if registered
            assert.equal(await this.ISOP.isStakeOfferer(account0, {from: account0}), true);
        });

        it('should not allow wallet to register to a stake offer pool if markup is larger then maximum', async function () {
            // deploy ISOP
            this.ISOP = await IssuerStakeOfferPool.new(this.registry.address, minAmountNeeded, maxMarkupPrice, {from: owner});

            // register wallet
            await this.swarmTokenMock.approve(this.ISOP.address, swmAmount, {from: account0});
            await shouldFail.reverting.withMessage(this.ISOP.register(swmAmount, maxMarkupPrice.add(1), {from: account0}),
                "Stake offerer registration failed: markup is to big");
        });

        it('should not allow wallet to register to a stake offer pool if amount of swm is lower than minimum', async function () {
            // deploy ISOP
            this.ISOP = await IssuerStakeOfferPool.new(this.registry.address, minAmountNeeded, maxMarkupPrice, {from: owner});

            // register wallet
            await this.swarmTokenMock.approve(this.ISOP.address, swmAmount, {from: account0});
            await shouldFail.reverting.withMessage(this.ISOP.register(minAmountNeeded.sub(1), markup, {from: account0}),
                "Stake offerer registration failed: SWM token amount is to small");
        });

        it('should be able to take funds from fundraising contract.', async function () {
            // deploy ISOP
            this.ISOP = await IssuerStakeOfferPool.new(this.registry.address, minAmountNeeded, maxMarkupPrice, {from: owner});

            // register wallet
            await this.swarmTokenMock.approve(this.ISOP.address, swmAmount, {from: account0});
            await this.ISOP.register(swmAmount, markup, {from: account0});

            // fundraising calling stake & mint with isop enabled
            await this.swarmPoweredFundraiseMock.stakeAndMint(this.ISOP.address, {from: account0});

            // assert.equal() // @TODO check if funds are taken

            // check if swm are transferred to src20registry
            // check if funds are transferred to stake issuer
            // check if calculation is right
        });

        it('should be able to stake & mint tokens.', async function () {
            // deploy ISOP
            this.ISOP = await IssuerStakeOfferPool.new(this.registry.address, minAmountNeeded, maxMarkupPrice, {from: owner});

            // register wallet
            await this.swarmTokenMock.approve(this.ISOP.address, swmAmount, {from: account0});
            await this.ISOP.register(swmAmount, markup, {from: account0});

            // fundraising calling stake & mint with isop enabled
            await this.swarmPoweredFundraiseMock.stakeAndMint(this.ISOP.address, {from: account0});

            // assert.equal() // @TODO check if stake&mint happened correctly

            // check if swm are transferred to src20registry
            // check if funds are transferred to stake issuer
            // check if calculation is right
        });

        it('should be able to go thought the whole take & stake & mint process.', async function () {
            // deploy ISOP
            this.ISOP = await IssuerStakeOfferPool.new(this.registry.address, minAmountNeeded, maxMarkupPrice, {from: owner});

            // register wallet
            await this.swarmTokenMock.approve(this.ISOP.address, swmAmount, {from: account0});
            await this.ISOP.register(swmAmount, markup, {from: account0});

            // fundraising calling stake & mint with isop enabled
            await this.swarmPoweredFundraiseMock.stakeAndMint(this.ISOP.address, {from: account0});

            // assert.equal() // @TODO check if stake & mint calculation is right

            // check if swm are transferred to src20registry
            // check if funds are transferred to stake issuer
            // check if calculation is right
        });
    });
});
