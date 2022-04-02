pragma solidity 0.8.13;
//SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";

/*                  
,--.   ,--. ,-----.    
|  |   |  |'  .-.  '   
|  |   |  ||  | |  |   
|  '--.|  |'  '-'  '-. 
`-----'`--' `-----'--' 
Liquidity is QUEEN
Next generation protocol owned liquidity.
                     */

contract Liquid {
    ///////////////////////
    // STATE
    ///////////////////////

    uint256 liqIndex;

    mapping(uint256 => LiqConfig) public liqConfig;
    //pack structs later
    struct LiqConfig {
        //time
        uint256 liqLength;
        uint256 liqStartTimestamp;
        //accounting
        uint256 liqTotalSize;
        uint256 liqSubscriptionSize;
        uint256 liqMinSubscriptionPrice;
        // relevant addresses
        address liqCreatorAddress;
        address protocolToken;
        address paymentToken;
        address routerAddress;
        address pairAddress;
    }

    mapping(uint256 => LiqInfo) public liqInfo;
    struct LiqInfo {
        uint256 totalPaymentTokenRecieved;
        uint256 totalLPTokensCreated;
        LiqState liqState;
    }
    enum LiqState {
        DOESNOTEXIST,
        PRELAUNCH,
        ONGOING,
        FINISHED
    }

    mapping(address => mapping(uint256 => UserContribution))
        public userContributions;
    struct UserContribution {
        uint256 amount;
        uint256 lastRedeemTimestamp;
        bool diamondHand;
    }

    ///////////////////////
    // MODIFIERS
    ///////////////////////

    modifier liqOpen(uint256 _liqIndex) {
        require(
            block.timestamp > liqConfig[_liqIndex].liqStartTimestamp &&
                block.timestamp <
                liqConfig[_liqIndex].liqStartTimestamp +
                    liqConfig[_liqIndex].liqLength,
            "Auction not open"
        );
        _;
    }

    modifier checkLiqValid(
        uint256 _totalTokenAmount,
        uint256 _liqSubscriptionSize,
        uint256 _liqStartTimestamp
    ) {
        require(
            _totalTokenAmount >= 2 * _liqSubscriptionSize,
            "Insuffcient size"
        );
        require(
            block.timestamp + 1 hours < _liqStartTimestamp,
            "Bad start time"
        );
        require(
            block.timestamp + 30 days > _liqStartTimestamp,
            "Bad start time"
        );
        _;
    }

    ///////////////////////
    // LIQ CONSTRUCTOR
    ///////////////////////

    constructor() {}

    ///////////////////////
    // LIQ CREATORS
    ///////////////////////

    function createLiq(
        uint256 _totalTokenAmount,
        uint256 _liqSubscriptionSize,
        uint256 _liqMinSubscriptionPrice,
        uint256 _liqLength,
        uint256 _liqStartTimestamp,
        address _protocolToken,
        address _paymentToken,
        address _routerAddress,
        address _factoryAddress
    )
        external
        checkLiqValid(
            _totalTokenAmount,
            _liqSubscriptionSize,
            _liqStartTimestamp
        )
    {
        liqIndex++;

        liqConfig[liqIndex].pairAddress = IUniswapV2Factory(_factoryAddress)
            .getPair(_protocolToken, _paymentToken);

        // check the pair exists
        require(
            liqConfig[liqIndex].pairAddress != address(0),
            "pair must exist"
        );

        // Protocol should have already approved us to take these tokens
        IERC20(_protocolToken).transfer(address(this), _totalTokenAmount);

        // set what we need for the auctionzs
        liqConfig[liqIndex].liqSubscriptionSize = _liqSubscriptionSize;
        liqConfig[liqIndex].liqMinSubscriptionPrice = _liqMinSubscriptionPrice;
        liqConfig[liqIndex].liqLength = _liqLength;
        liqConfig[liqIndex].protocolToken = _protocolToken;
        liqConfig[liqIndex].paymentToken = _paymentToken;
        liqConfig[liqIndex].routerAddress = _routerAddress;
        liqConfig[liqIndex].liqCreatorAddress = msg.sender;

        // also check reasonable start time paratmeter.
        liqConfig[liqIndex].liqStartTimestamp = _liqStartTimestamp;
    }

    // If the config is incorrect there should be some ability to back out

    ///////////////////////
    // LIQ APEOOORS
    ///////////////////////

    // ape into the sepcific liquidity event
    function ape(
        uint256 _liqIndex,
        uint256 _amountToApe,
        bool _diamondHand
    ) external liqOpen(_liqIndex) {
        require(_amountToApe > 0, "ape harder");

        // enforce not too much ape edge case after hack.
        IERC20(liqConfig[_liqIndex].paymentToken).transfer(
            address(this),
            _amountToApe
        );

        userContributions[msg.sender][_liqIndex].amount += _amountToApe;
        userContributions[msg.sender][_liqIndex].diamondHand = _diamondHand; // set this always
        liqInfo[_liqIndex].totalPaymentTokenRecieved += _amountToApe;
    }

    // ape out of the sepcific liquidity event
    function unApe(uint256 _liqIndex, uint256 _amountToApeOut)
        external
        liqOpen(_liqIndex)
    {
        require(
            _amountToApeOut <= userContributions[msg.sender][_liqIndex].amount,
            "naughty ape"
        );

        // cannot withdraw in last day. Make this neater.
        require(
            block.timestamp + 1 days <
                liqConfig[_liqIndex].liqStartTimestamp +
                    liqConfig[_liqIndex].liqLength,
            "Cannot withdraw in last day"
        );

        userContributions[msg.sender][_liqIndex].amount -= _amountToApeOut;
        liqInfo[_liqIndex].totalPaymentTokenRecieved -= _amountToApeOut;

        IERC20(liqConfig[_liqIndex].paymentToken).transfer(
            msg.sender,
            _amountToApeOut
        );
    }

    ///////////////////////
    // LIQ FINALIzATION
    ///////////////////////

    // function finalizeAuction(uint256 _liqIndex) external {
    //     require(
    //         block.timestamp >
    //             liqConfig[_liqIndex].liqStartTimestamp +
    //                 liqConfig[_liqIndex].liqLength,
    //         "Auction not ended"
    //     );
    //     // require(
    //     //     !liqConfig[_liqIndex].auctionFinalized,
    //     //     "auction already finalized"
    //     // );

    //     // liqConfig[_liqIndex].auctionFinalized = true;

    //     if (
    //         liqInfo[_liqIndex].totalPaymentTokenRecieved <
    //         liqConfig[_liqIndex].liqMinSubscriptionPrice
    //     ) {
    //         // liqConfig[_liqIndex].auctionDidNotPass = true;
    //         return; // auction didn't pass people should withdraw.
    //     }

    //     // Need to ensure permissonless addition of this liquidity cannot be exploited
    //     _addTheLiquidity(_liqIndex);

    //     // perform other work!
    // }

    // function _addTheLiquidity(uint256 _liqIndex) internal {
    //     address liqPairAddress = liqConfig[_liqIndex].pairAddress;

    //     // uint256 balanceBefore = IUniswapV2Pair(liqPairAddress).balanceOf(
    //     //     address(this)
    //     // );

    //     // It is not safe to look up the reserve ratio from within a transaction and rely on it as a price belief,
    //     // as this ratio can be cheaply manipulated to your detriment.
    //     // don't want to get rugged here. We need slippage tolerance and or a price estimate.zs
    //     // https://docs.uniswap.org/protocol/V2/guides/smart-contract-integration/providing-liquidity
    //     // think of solution such as simply encoding the price belief in the input and making this function permissioned.

    //     // address token0 = IUniswapV2Pair(auction.pairAddress).token0();
    //     (uint112 reserve0, uint112 reserve1, ) = IUniswapV2Pair(liqPairAddress)
    //         .getReserves();

    //     (
    //         uint256 reserveProtocolToken,
    //         uint256 reserveOtherToken
    //     ) = (IUniswapV2Pair(liqPairAddress).token0() ==
    //             liqConfig[_liqIndex].protocolToken)
    //             ? (uint256(reserve0), uint256(reserve1))
    //             : (uint256(reserve1), uint256(reserve0));

    //     // calculate exact ratio to put it in at.
    //     uint256 amountOfProtocolTokenToPutIn = (reserveOtherToken *
    //         liqInfo[_liqIndex].totalPaymentTokenRecieved) /
    //         reserveProtocolToken;

    //     //check we weren't sandwidched using chainlink
    //     // require(
    //     //     (fairPrice * 997) / 1000 <
    //     //         (reserveOtherToken * 1e18) / reserveProtocolToken
    //     // );
    //     // require(
    //     //     (fairPrice * 1003) / 1000 >
    //     //         (reserveOtherToken * 1e18) / reserveProtocolToken
    //     // );

    //     // give router the necessary allowance
    //     // maximal approve rather in contructor
    //     // IERC20(liq.protocolToken).approve(
    //     //     liq.routerAddress,
    //     //     amountOfProtocolTokenToPutIn
    //     // );
    //     // IERC20(liq.paymentToken).approve(
    //     //     liq.routerAddress,
    //     //     liqInfo[_liqIndex].totalPaymentTokenRecieved
    //     // );
    //     IUniswapV2Router02(liqConfig[_liqIndex].routerAddress).addLiquidity(
    //         liqConfig[_liqIndex].protocolToken,
    //         liqConfig[_liqIndex].paymentToken,
    //         amountOfProtocolTokenToPutIn, // amountADesired
    //         liqInfo[_liqIndex].totalPaymentTokenRecieved,
    //         amountOfProtocolTokenToPutIn, // use another price method to ensure this isn't an issue.
    //         liqInfo[_liqIndex].totalPaymentTokenRecieved,
    //         address(this),
    //         block.timestamp // must execute atomically obvs
    //     );

    //     // liqInfo[_liqIndex].totalLPTokensCreated =
    //     //     IUniswapV2Pair(liqPairAddress).balanceOf(address(this)) -
    //     //     balanceBefore;
    // }

    /*╔═════════════════════════════╗
      ║    success redeem events    ║
      ╚═════════════════════════════╝*/

    // function userRedeemTokens(uint256 _liqIndex) external {
    //     // require(
    //     //     liqConfig[_liqIndex].auctionFinalized,
    //     //     "auction not finalized"
    //     // );
    //     //only once auction is over
    //     UserContribution storage user = userContributions[msg.sender][
    //         _liqIndex
    //     ];

    //     uint256 baseAmountForUser = (liqConfig[_liqIndex].liqSubscriptionSize *
    //         user.amount) / liqInfo[_liqIndex].totalPaymentTokenRecieved;

    //     if (user.lastRedeemTimestamp == 0) {
    //         user.lastRedeemTimestamp = block.timestamp;
    //     }

    //     // todo allocate bonus liquidity
    //     uint256 vestingPeriod = (user.diamondHand) ? 90 days : 180 days;
    //     uint256 vestEndTime = liqConfig[_liqIndex].liqStartTimestamp +
    //         liqConfig[_liqIndex].liqLength +
    //         vestingPeriod;

    //     uint256 vestedTill = (block.timestamp > vestEndTime)
    //         ? vestEndTime
    //         : block.timestamp;

    //     // safe math will revert if they try redeem again past their vest period
    //     uint256 vestedAmount = (baseAmountForUser *
    //         (vestedTill - user.lastRedeemTimestamp)) / vestingPeriod;

    //     user.lastRedeemTimestamp = block.timestamp;

    //     IERC20(liqConfig[_liqIndex].protocolToken).transfer(
    //         msg.sender,
    //         vestedAmount
    //     );
    // }

    // function protocolRedeemLPtokens(uint256 _liqIndex) external {
    //     // require(
    //     //     liqConfig[_liqIndex].auctionFinalized,
    //     //     "auction not finalized"
    //     // );
    //     uint256 amount = liqInfo[_liqIndex].totalLPTokensCreated;

    //     liqInfo[_liqIndex].totalLPTokensCreated = 0;
    //     IUniswapV2Pair(liqConfig[_liqIndex].pairAddress).transferFrom(
    //         address(this),
    //         liqConfig[_liqIndex].liqCreatorAddress,
    //         amount
    //     );
    // }

    /*╔═════════════════════════════╗
      ║    Failed event withdrawls  ║
      ╚═════════════════════════════╝*/

    // function withdrawFailedEvent(uint256 _liqIndex) external {
    //     // require(
    //     //     liqConfig[_liqIndex].auctionDidNotPass,
    //     //     "can only exit in failed event"
    //     // );
    //     uint256 amount = userContributions[msg.sender][_liqIndex].amount;
    //     userContributions[msg.sender][_liqIndex].amount = 0;

    //     IERC20(liqConfig[_liqIndex].paymentToken).transfer(
    //         msg.sender,
    //         amount
    //     );
    // }

    //     function withdrawFailedEventProtocol(uint256 _liqIndex) external {
    //         // require(
    //         //     liqConfig[_liqIndex].auctionDidNotPass,
    //         //     "can only exit in failed event"
    //         // );
    //         uint256 amount = liqConfig[_liqIndex].liqTotalSize;
    //         liqConfig[_liqIndex].liqTotalSize = 0;

    //         IERC20(liqConfig[_liqIndex].protocolToken).transfer(
    //             liqConfig[_liqIndex].liqCreatorAddress,
    //             amount
    //         );
    //     }
}
