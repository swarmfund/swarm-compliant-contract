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

contract('Third party actions', async function ([_, whitelistManager /*authority*/, owner, issuer, contributor]) {
    const ercTotalSupply = new BN(10000);
    const amount = new BN(10);
    const minAmount = new BN(11);
    const maxAmount = new BN(100);

    beforeEach(async function () {
        this.swarmPoweredFundraiseMock = await SwarmPoweredFundraiseMock.new({from: owner});

        this.acceptedToken = await Erc20Token.new(owner, ercTotalSupply, {from: owner});
        this.notAcceptedToken = await Erc20Token.new(owner, ercTotalSupply, {from: owner});
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

        it('should be able to setup ISOP as a swarm');

        it('should allow any wallet to register to a stake offer pool if desirable condition are meat.');

        it('should be able to take funds from fundraising contract.');

        it('should be able to stake & mint tokens');

        it('should be able to go thought the whole take & stake & mint process');
    });
});
