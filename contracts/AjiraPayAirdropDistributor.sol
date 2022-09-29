// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/access/AccessControl.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';


contract AjiraPayAirdropDistributor is Ownable, AccessControl, ReentrancyGuard{
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IERC20 public rewardToken;

    bool public isAirdropActive = false;
    bool public isClaimOpen = false;

    bytes32 constant public MANAGER_ROLE = keccak256('MANAGER_ROLE');

    mapping(address => uint) public userRewards;
    mapping(address => bool) public isExistingWinner;
    mapping(address => bool) public hasClaimedRewards;

    uint public maxRewardCapPerUser;
    uint public minRewardCapPerUser;

    event AirdropActivated(address indexed caller, IERC20 indexed token, uint indexed timestamp);
    event AirdropDeActivated(address indexed caller, IERC20 indexed token, uint indexed timestamp);
    event RewardTokenSet(address indexed caller, IERC20 indexed token, uint timestamp);
    event NewWinner(address indexed caller, address indexed winner, uint indexed amount, uint timestamp);
    event ClaimFor(address indexed caller, address indexed beneciary, uint indexed amount, uint timestamp);
    event Claim(address indexed beneficiary, uint indexed amount, uint timestamp);
    event UserRewardUpdated(address indexed caller, address indexed beneficiary, uint prevRewardAmount, uint indexed newRewardAmount, uint timestamp);
    event ClaimsOpened(address indexed caller, uint indexed timestamp);
    event ClaimsClosed(address indexed caller, uint indexed timestamp);

    modifier isActive(){
        require(isAirdropActive == true,"Airdrop not active");
        _;
    }

    modifier isNotActive(){
        require(isAirdropActive == false,"Airdrop is active");
        _;
    }

    modifier nonZeroAddress(address _account){
        require(_account != address(0),"Invalid Account");
        _;
    }

    modifier isExistingWinnerAccount(address _account){
        require(isExistingWinner[_account] == true,"Not a beneficiary");
        _;
    }

    modifier hasNotClaimedReward(address _account){
        require(hasClaimedRewards[_account] == false,"Rewards claimed already");
        _;
    }

    modifier claimOpen(){
        require(isClaimOpen == true,"Claim Not Active");
        _;
    }

    modifier claimClosed(){
        require(isClaimOpen == false,"Claim Not Active");
        _;
    }

    constructor(IERC20 _token, uint _minRewardCap, uint _maxRewardCap, uint _tokenDecimals){
        require(_tokenDecimals > 0 && _tokenDecimals <= 18,"Invalid Decimals Number");
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(MANAGER_ROLE, _msgSender());
        
        rewardToken = _token;
        minRewardCapPerUser = _minRewardCap.mul(10 ** _tokenDecimals);
        maxRewardCapPerUser = _maxRewardCap.mul(10 ** _tokenDecimals);
    }

    function activateAirdrop() public onlyRole(MANAGER_ROLE) isNotActive{
        isAirdropActive = true;
        emit AirdropActivated(_msgSender(), rewardToken, block.timestamp);
    }

    function deactivateAirdrop() public onlyRole(MANAGER_ROLE) isActive{
        isAirdropActive = false;
        emit AirdropDeActivated(_msgSender(), rewardToken, block.timestamp);
    }

    function addWinner(address _winner, uint _amount) public nonZeroAddress(_winner) onlyRole(MANAGER_ROLE){
        require(_amount > 0,"Amount is zero");
        require(_amount < rewardToken.balanceOf(address(this)) && _amount <= maxRewardCapPerUser,"Cap Reached");
        if(isExistingWinner[_winner] == false){ isExistingWinner[_winner] = true;}
        userRewards[_winner] = userRewards[_winner].add(_amount);
        emit NewWinner(_msgSender(), _winner, _amount, block.timestamp);
    }

    function updateWinnerReward(address _winner, uint _newRewardAmount) public nonZeroAddress(_winner) isExistingWinnerAccount(_winner) onlyRole(MANAGER_ROLE) nonReentrant {
        require(_newRewardAmount > 0,"Amount is zero");
        uint256 rewardBefore = userRewards[_winner];
        uint256 totalRewards = rewardBefore.add(_newRewardAmount);
        require(_newRewardAmount < rewardToken.balanceOf(address(this)) && _newRewardAmount <= maxRewardCapPerUser,"Cap Reached");
        require(totalRewards <= rewardToken.balanceOf(address(this)) && totalRewards <= maxRewardCapPerUser,"Cap Reached");
        userRewards[_winner] = rewardBefore.add(_newRewardAmount);
        uint256 rewardAfter = userRewards[_winner];
        if(hasClaimedRewards[_winner] == true && rewardAfter >0){
            hasClaimedRewards[_winner] = false;
        }
        emit UserRewardUpdated(_msgSender(), _winner, rewardBefore, rewardAfter, block.timestamp);
    }

    function claimAirdrop() public{
        (uint256 _claimedRewardAmount) = _performClaim(_msgSender());
        emit Claim(_msgSender(), _claimedRewardAmount, block.timestamp);
    }

    function claimAirdropFor(address _beneficiary) public onlyRole(MANAGER_ROLE) {
        (uint256 _claimedRewardAmount) = _performClaim(_beneficiary);
        emit ClaimFor(_msgSender(),_beneficiary, _claimedRewardAmount, block.timestamp);
    }

    function setRewardToken(address _token) public nonZeroAddress(_token) onlyRole(MANAGER_ROLE) isNotActive{
        rewardToken = IERC20(_token);
        emit RewardTokenSet(_msgSender(), rewardToken, block.timestamp);
    }

    function activateClaims() public onlyRole(MANAGER_ROLE) isActive claimClosed{
        isClaimOpen = true;
        emit ClaimsOpened(_msgSender(), block.timestamp);
    }

    function deActivateClaims() public onlyRole(MANAGER_ROLE) isActive claimOpen{
        isClaimOpen = false;
        emit ClaimsClosed(_msgSender(), block.timestamp);
    }

    function getAirdropTotalSupply() public view returns(uint256){
        return rewardToken.balanceOf(address(this));
    }

    //Internal functions
    function _performClaim(address _beneficiary) private nonZeroAddress(_beneficiary) isExistingWinnerAccount(_beneficiary) hasNotClaimedReward(_beneficiary) isActive claimOpen nonReentrant returns(uint256){
        uint256 rewardAmount = userRewards[_beneficiary];
        require(rewardToken.transfer(_beneficiary,rewardAmount),"Failed to send reward");
        userRewards[_beneficiary] = 0;
        hasClaimedRewards[_beneficiary] = true;
        return rewardAmount;
    }
}