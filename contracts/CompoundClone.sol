pragma solidity >=0.6.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

abstract contract CompoundClone {
    using SafeMath for uint256;

    mapping (address => uint) public collateral; // user's ETH collateral amount
    mapping (address => mapping (address => uint)) public userSupply; // user's supplied amounts per token: user -> token -> supply amount
    mapping (address => mapping (address => uint)) public userBorrows; // user's borrow amounts per token: user -> token -> borrowed amount

    address public eth;
    address public usdc;

    uint public maxBorrow = 700; // user's can borrow maximum 70% of collateral

    /**
     * @dev lenders deposit `amount` of `token`
     *    transfer token from msg.sender and give wrapped token(similiar with cToken)
     * @param token - address of weth or usdc
     * @param amount - amount to supply
     */
    function supply(address token, uint amount) external virtual {
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        userSupply[msg.sender][token] = userSupply[msg.sender][token].add(amount);
        // more functions.... including deposit supply to Compound or Aave to get interest
    }

    /**
     * @dev lenders withdraw `amount` of `token`
     *    transfer token from msg.sender and give wrapped token(similiar with cToken)
     * requirements
     * - cannot withdraw eth if remaining balance is lower than collateral
     *
     * @param token - address of weth or usdc
     * @param amount - amount to withdraw
     */
    function withdrawSupply(address token, uint amount) external virtual {
        IERC20(token).transfer(msg.sender, amount);
        userSupply[msg.sender][token] = userSupply[msg.sender][token].sub(amount);
        if (token == eth) {
            require (userSupply[msg.sender][eth] >= collateral[msg.sender].add(amount), 'no enough supply');
        }
        // more functions.... including deposit supply to Compound or Aave to get interest
    }

    /**
     * @dev Calculate eth value for `amount` of `token` (using price oracle)
     *
     * @param token - address usdc
     * @param amount - amount to get
     */
    function valueInEth(address token, uint amount) public view virtual returns (uint256);

    /**
     * @dev borrow `amount` of `token`
     *
     * @param token - address of weth or usdc
     * @param amount - amount to borrow
     */
    function borrow(address token, uint amount) external virtual {
        updateBorrowInterest(token, msg.sender);
        uint256 maxBorrowPct = maxBorrowOfUser(msg.sender);
        if (token == eth) {
            require (collateral[msg.sender].mul(maxBorrowPct).div(1000) >= totalRepayAmount(msg.sender).add(amount), 'no collateral');
        } else {
            require (collateral[msg.sender].mul(maxBorrowPct).div(1000) >= valueInEth(token, amount).add(totalRepayAmount(msg.sender)), 'no collateral');
        }
        uint256 balance = IERC20(token).balanceOf(address(this));
        if (balance < amount) {
            // withdraw from compound
        }
        IERC20(token).transfer(msg.sender, amount);
        userBorrows[msg.sender][token] = userBorrows[msg.sender][token].add(amount);
        // ...
    }

    /**
     Update borrow interest
     */
    function updateBorrowInterest(address token, address user) public virtual;

    /**
     * @dev repay `amount` of `token`
     *
     * @param token - address of weth or usdc
     * @param amount - amount to borrow
     */
    function repay(address token, uint amount) external virtual {
        updateBorrowInterest(eth, msg.sender);
        updateBorrowInterest(usdc, msg.sender);
        require(ableToRepay(msg.sender), 'unable to repay');
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        userBorrows[msg.sender][token] = userBorrows[msg.sender][token].sub(amount.sub(amount.mul(borrowInterestOfUser(msg.sender, token).div(1000))));
        // ...
    }

    /**
     * @dev check if borrow amount is exceed than collateral
     */
    function ableToRepay(address user) public view returns (bool) {
        uint totalBorroow = userBorrows[user][eth].add(userBorrows[user][eth].mul(borrowInterestOfUser(user, eth).div(1000)))
            + valueInEth(usdc, userBorrows[user][usdc].add(userBorrows[user][usdc].mul(borrowInterestOfUser(user, usdc).div(1000))));
        return collateral[user] >= totalBorroow;
    }

    /**
     * @dev get total repay amount of user in eth
     */
    function totalRepayAmount(address user) public view returns (uint) {
        uint totalBorroow = userBorrows[user][eth].add(userBorrows[user][eth].mul(borrowInterestOfUser(user, eth).div(1000)))
            + valueInEth(usdc, userBorrows[user][usdc].add(userBorrows[user][usdc].mul(borrowInterestOfUser(user, usdc).div(1000))));
        return totalBorroow;
    }

    /**
     * @dev increase collateral amount from user's eth supply
     * @param amount - amount of supply to convert to collateral
     */
    function increaseCollateral(uint amount) external virtual {
        collateral[msg.sender] = collateral[msg.sender].add(amount);
        require (userSupply[msg.sender][eth] >= collateral[msg.sender].add(amount), 'no enough supply');
        // more functions....
    }

    /**
     * @dev decrease collateral amount
     * @param amount - amount of collateral to decrease
     */
    function decreaseCollateral(uint amount) external virtual {
        require(totalRepayAmount(msg.sender) == 0, 'unable to reduce collateral');
        collateral[msg.sender] = collateral[msg.sender].sub(amount);
        // more functions....
    }

    /**
     * @dev get creditScore of user
     */
    function creditScore(address user) public view virtual returns (uint256);

    /**
     * @dev calculate max borrow of user depends on his creditScore
     * @return max borrow percentage of user - max: maxBorrow, min: 0
     */
    function maxBorrowOfUser(address user) public view virtual returns (uint256);

    /**
     * @dev calculate borrow interest of user depends on his creditScore, collateral ratio and supply of borrowed asset
     * @return max borrow percentage of user - max: maxBorrow, min: 0
     */
    function borrowInterestOfUser(address user, address token) public view virtual returns (uint256);

    /**
     * @dev return collateral ratio
     */
    function collateralRatio() public view virtual returns (uint256);
}
