pragma solidity >=0.6.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Bet is Ownable {
    using SafeMath for uint;

    event OnBetFinish(address indexed firstPlace, address indexed secondPlace, address indexed thirdPlace);

    IERC20 public betToken;
    uint256 constant BET_AMOUNT = 50 * (10**18);

    uint256 constant MAX_BET_COUNT = 3;
    uint256 constant FEE = 1;
    uint256 public currentBet;

    mapping (uint256 => address) public betPlayer;

    constructor(IERC20 _betToken) public {
        betToken = _betToken;
    }

    function bet() external {
        require (currentBet < MAX_BET_COUNT, 'bet finished');
        betToken.transferFrom(msg.sender, address(this), BET_AMOUNT);
        betToken.transfer(owner(), BET_AMOUNT.mul(FEE).div(100));
        betPlayer[currentBet] = msg.sender;
        currentBet = currentBet.add(1);
    }

    function finishGame() external /* onlyOwner */{
        require (currentBet == MAX_BET_COUNT, 'bet not finished');
        
        uint rand = uint(keccak256(abi.encodePacked(betPlayer[0], betPlayer[1], betPlayer[2], block.timestamp, block.difficulty, blockhash(block.number))));
        uint first = rand.mod(3);
        uint balance = betToken.balanceOf(address(this));
        betToken.transfer(betPlayer[first], balance.mul(2).div(3));
        uint second = rand.mod(2);
        uint third = 1 - second;
        if (first == 0) {
            second = second.add(1);
            third = third.add(1);
        } else if (first == 1) {
            if (second == 1) {
                second = 2;
            }
            third = 2 - second;
        }
        betToken.transfer(betPlayer[second], betToken.balanceOf(address(this)));

        emit OnBetFinish(betPlayer[first], betPlayer[second], betPlayer[third]);

        currentBet = 0;
    }
}
