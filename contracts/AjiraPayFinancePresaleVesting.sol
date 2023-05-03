// SPDX-License-Identifier: MIT
pragma solidity =0.8.4;
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol';

contract AjiraPayFinancePresaleVesting{
    IERC20 public ajiraPayFinanceToken;
    AggregatorV3Interface internal priceFeed;

    address payable public treasury;
    address private constant CHAINLINK_MAINNET_BNB_USD_PRICEFEED_ADDRESS = 0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE;

    address[] public investors;
    
    bool public isPresaleOpen = false;
    bool public isPresalePaused = false;
    bool public isOpenForClaims = false;
    
    bool public isPhase1Active = true;
    bool public isPhase2Active = false;
    bool public isPhase3Active = false;
    
    uint public totalInvestors = 0;
    uint public totalWeiRaised = 0;
    uint public totalTokensSold = 0;
    uint public totalTokensClaimed = 0;

    uint256 public minimumContribution = 10 * 10 ** 18; // 10 USD
    uint public phase1PricePerTokenInWei = 6 * 10 ** 18; //0.06 USD
    uint public phase2PricePerTokenInWei = 7 * 10 ** 18; //0.07 USD
    uint public phase3PricePerTokenInWei = 8 * 10 ** 18; //0.08 USD

    uint public maxPossibleInvestmentInWei = 10000 * 10**18;
    
    uint public totalTokensSoldInPhase1 = 0;
    uint public totalTokensSoldInPhase2 = 0;
    uint public totalTokensSoldInPhase3 = 0;

    uint public totalWeiRaisedInPhase1 = 0;
    uint public totalWeiRaisedInPhase2 = 0;
    uint public totalWeiRaisedInPhase3 = 0;

    uint256 public phase1TotalTokensToSell = 3_000_000 * 1e18;
    uint256 public phase2TotalTokensToSell = 5_000_000 * 1e18;
    uint256 public phase3TotalTokensToSell = 7_000_000 * 1e18;

    uint public maxTokenCapForPresale = 15_000_000 * 1e18;
    uint public maxTokensToPurchasePerWallet = 2_000_000 * 1e18;

    uint256 public totalVestingRewards = 0;

    uint256 public claimsStartDate = 0;

    uint256 public phase1Start = 0;
    uint256 public phase1End = 7 days;

    uint256 public phase2Start = 0;
    uint256 public phase2End = 7 days;

    uint256 public phase3Start = 0;
    uint256 public phase3End = 7 days;

    mapping(address => uint) public totalTokenContributionsByUser;
    mapping(address => uint) public totalTokenContributionsClaimedByUser;
    mapping(address => uint) public totalBNBInvestmentsByIUser;
    mapping(address => bool) public isActiveInvestor;

    mapping(address => uint256) public totalPersonalTokenInvestmentPhase1;
    mapping(address => uint256) public totalPersonalTokenInvestmentPhase2;
    mapping(address => uint256) public totalPersonalTokenInvestmentPhase3;

    mapping(address => uint256) public totalPersonalWeiInvestmentPhase1;
    mapping(address => uint256) public totalPersonalWeiInvestmentPhase2;
    mapping(address => uint256) public totalPersonalWeiInvestmentPhase3;

    mapping(address => uint) public totalPersonalRewardsFromVesting;

    address payable public admin;

    struct Vesting{
        address payable beneficiary;
        uint256 amountBought;
        uint256 rewardAmount;
        uint256 totalClaimable;
        uint256 startDate;
        uint256 unlockDate;
        bool isClaimedFull;
    }

    Vesting[] public vestedPurchases;

    mapping(address => Vesting) public userVestingRecord;
    mapping(address => Vesting[]) public personalUserVestedPurchases;

    enum VestingLock{
        _0_WEEKS, 
        _4_WEEKS,
        _8_WEEKS,
        _12_WEEKS,
        _16_WEEKS, 
        _20_WEEKS,
        _24_WEEKS
    }

    event Contribute(
        address indexed beneficiary, 
        uint indexed weiAmount, 
        uint indexed tokenAmountBought, 
        uint timestamp
    );

    event VestingPurchase(
        address indexed beneficiary, 
        uint indexed weiAmount, 
        uint indexed tokenAmountBought, 
        uint256 vestingPeriod,
        uint256 totalVestingRewards,
        uint timestamp
    );

    event Claim(
        address indexed beneficiary, 
        uint indexed tokenAmountReceived, 
        uint indexed timestamp
    );

    modifier presaleOpen(){
        require(isPresaleOpen == true,"Sale Closed");
        _;
    }

    modifier presaleClosed(){
        require(isPresaleOpen == false,"Sale Open");
        _;
    }

    modifier presalePaused(){
        require(isPresalePaused == true,"Presale Not Paused");
        _;
    }

    modifier presaleUnpaused(){
        require(isPresalePaused == false,"Presale Paused");
        _;
    }

    modifier nonZeroAddress(address _account){
        require(_account != address(0),"Invalid Account");
        _;
    }

    modifier claimsOpen(){
        require(isOpenForClaims == true,"Claims Not Open");
        _;
    }

    modifier onlyOwner(){
        require(msg.sender == admin,"Uauthorized action");
        _;
    }

    constructor(address _token, address payable _treasury){
        require(_token != address(0),"Invalid Address");
        require(_treasury != address(0),"Invalid Address");

        ajiraPayFinanceToken = IERC20(_token); 
        treasury = _treasury;
        priceFeed = AggregatorV3Interface(CHAINLINK_MAINNET_BNB_USD_PRICEFEED_ADDRESS);
        admin = payable(msg.sender);
    }

    function setPresalePauseStatus(bool _status) external onlyOwner{
        isPresalePaused = _status;
    }

    function setPresaleClaimsStatus(bool _status) external onlyOwner{
        isOpenForClaims = _status;
        if(isOpenForClaims){
            claimsStartDate = block.timestamp;
        }
    }

    function setPresaleProgressStatus(bool _status) external onlyOwner{
        isPresaleOpen = _status;
        if(isPresaleOpen){
            phase1Start = block.timestamp;
            phase1End = phase1Start + 7 days;

            phase2Start = phase1End;
            phase2End = phase2Start + 7 days;

            phase3Start = phase2End;
            phase3End = phase3Start + 7 days;
        }
    }

    function activatePhase1() external onlyOwner{
        _activatePhase1();
    }
    
    function activatePhase2() external onlyOwner{
        _activatePhase2();
    }

    function activatePhase3() external onlyOwner{
        _activatePhase3();
    }

    function claimUnsoldTokens() public onlyOwner presaleClosed{
        _refundUnsoldTokens(msg.sender);
    }

    function updateTreasury(address payable _newTreasury) public onlyOwner 
    nonZeroAddress(_newTreasury) 
    presalePaused
    {
        treasury = _newTreasury;
    }

    function updatePresalePhaseAmount(uint256 _phase1Amount, uint256 _phase2Amount, uint256 _phase3Amount) external onlyOwner{
        require(_phase1Amount > 0,"Invalid Token Amount");
        require(_phase2Amount > 0,"Invalid Token Amount");
        require(_phase3Amount > 0,"Invalid Token Amount");
        phase1TotalTokensToSell = _phase1Amount * 1e18;
        phase2TotalTokensToSell = _phase2Amount * 1e18;
        phase3TotalTokensToSell = _phase3Amount * 1e18;
    }
    
    function contribute() external payable presaleOpen presaleUnpaused{
        uint256 pricePerToken = _getTokenPriceByPhase();
        (uint256 price, uint256 decimals) = _getLatestBNBPriceInUSD();
        uint256 weiAmount = msg.value;
        uint256 usdAmountFromValue = weiAmount * price / (10 ** decimals);
        require(weiAmount > 0, "No Amount Specified");

        require(usdAmountFromValue >= minimumContribution,"Contribution below minimum");
        require(usdAmountFromValue <= maxPossibleInvestmentInWei,"Contribution Above Maximum");

        uint256 tokenAmount = usdAmountFromValue * 100 * (10 ** 18) / pricePerToken;
        uint256 totalTokensBoughtByUser = totalTokenContributionsByUser[msg.sender];
        require(totalTokensBoughtByUser + tokenAmount <= maxTokensToPurchasePerWallet,"Max Tokens Per Wallet Reached");
        require(tokenAmount <= maxTokenCapForPresale,"Max Cap Reached");

        totalTokenContributionsByUser[msg.sender] += tokenAmount;
        totalBNBInvestmentsByIUser[msg.sender] += weiAmount;
        totalTokensSold += tokenAmount;
        totalWeiRaised += weiAmount;
        _updateInvestorCountAndStatus();
        _updatePresalePhaseParams(tokenAmount, weiAmount);
        _updateInvestorContributionByPresalePhase(msg.sender,weiAmount,tokenAmount );
        _checkDurations();
        _checkPresaleEndStatus();
        _forwardFunds();
        
        emit Contribute(msg.sender, weiAmount, tokenAmount, block.timestamp);
    }

    function claim() external claimsOpen{
        uint256 totalAmountClaimable;
        Vesting[] storage userVestedSchedules = personalUserVestedPurchases[msg.sender];
       
        if(userVestedSchedules.length > 0){
             for(uint256 i = 0; i < userVestedSchedules.length; i++){
                if(block.timestamp > userVestedSchedules[i].unlockDate && !userVestedSchedules[i].isClaimedFull){
                    uint256 unvestedTokens = totalTokenContributionsByUser[msg.sender];
                    uint256 vestedTokens = userVestedSchedules[i].totalClaimable;
                    totalAmountClaimable = vestedTokens + unvestedTokens;
                    userVestedSchedules[i].isClaimedFull = true;
                    totalPersonalRewardsFromVesting[msg.sender] -= vestedTokens;
            }
        }
        }else{
            totalAmountClaimable = totalTokenContributionsByUser[msg.sender];
        }       
        
        require(totalAmountClaimable > 0,"Insufficient Token Claims");
        require(
            IERC20(ajiraPayFinanceToken).transfer(msg.sender, totalAmountClaimable),
            "Failed to send tokens"
        );
        totalTokenContributionsByUser[msg.sender] = 0;
        _updateInvestorContributionAfterClaims(totalAmountClaimable);
        emit Claim(msg.sender, totalAmountClaimable, block.timestamp);
    }
    
    function updateAdmin(address payable _newAdmin) external onlyOwner{
        require(_newAdmin != address(0),"Zero Address");
        admin = _newAdmin;
    }

    function recoverBNB() public onlyOwner{
        uint256 balance = address(this).balance;
        require(balance > 0,"Insufficient Contract Balance");
        treasury.transfer(balance);
    }

    function updateMaxTokenCapForPresale(uint256 _amount) public onlyOwner{
        maxTokenCapForPresale = _amount * 1e18;
    }

    function setPresalePhasePrice(uint256 _phase1Price, uint256 _phase2Price, uint256 _phase3Price) external onlyOwner{
        phase1PricePerTokenInWei = _phase1Price * 10 ** 18;
        phase2PricePerTokenInWei = _phase2Price * 10 ** 18;
        phase3PricePerTokenInWei = _phase3Price * 10 ** 18;
    }

    receive() external payable{}

    fallback() external payable{}

    function _getLatestBNBPriceInUSD() private view returns(uint256, uint256){
        (, int256 price, , , ) = priceFeed.latestRoundData();
        uint256 decimals = priceFeed.decimals();
        return (uint256(price), decimals);
    }

    function _forwardFunds() private{
        treasury.transfer(msg.value);
    }
    
    function _refundUnsoldTokens(address _destination) private{
        uint256 availableTokenBalance = ajiraPayFinanceToken.balanceOf(address(this));
        uint256 totalToDeduct = totalTokensSold + totalVestingRewards;
        uint256 refundableBalance = availableTokenBalance - totalToDeduct;
        require(refundableBalance > 0,"Insufficient Token Balance");
        require(refundableBalance <= availableTokenBalance,"Excess Token Withdrawals");
        require(ajiraPayFinanceToken.transfer(_destination, refundableBalance),"Failed To Refund Tokens");
    }

    function _setPresaleClosed() private{
        isPresaleOpen = false;
    }

    function _activatePhase1() private{
        isPhase1Active = true;
        isPhase2Active = false;
        isPhase3Active = false;
    }

    function _activatePhase2() private{
        isPhase2Active = true;
        isPhase1Active = false;
        isPhase3Active = false;
    }

    function _activatePhase3() private{
        isPhase3Active = true;
        isPhase1Active = false;
        isPhase2Active = false;
    }

    function _updateInvestorCountAndStatus() private{
        if(isActiveInvestor[msg.sender] == false){
            totalInvestors += 1;
            investors.push(msg.sender);
            isActiveInvestor[msg.sender] = true;
        }
    }

    function _updatePresalePhaseParams(uint256 _tokenAmount, uint256 _weiAmount) private{
        if(isPhase1Active){
            unchecked{
                totalTokensSoldInPhase1 += _tokenAmount;
                totalWeiRaisedInPhase1 += _weiAmount;
            }
        }else if(isPhase2Active){
            unchecked{
                totalTokensSoldInPhase2 += _tokenAmount;
                totalWeiRaisedInPhase2 += _weiAmount;
            }
        }else{
             unchecked{
                totalTokensSoldInPhase3 += _tokenAmount;
                totalWeiRaisedInPhase3 += _weiAmount;
            }
        }
    }

    function _checkPresaleEndStatus() private{
        if(totalTokensSold > maxTokenCapForPresale){
             _setPresaleClosed();
        }
    }

    function _getTokenPriceByPhase() private view returns(uint256){
        if(isPhase1Active){
            return phase1PricePerTokenInWei;
        }else if(isPhase2Active){
            return phase2PricePerTokenInWei;
        }else{
            return phase3PricePerTokenInWei;
        }
    }

    function _updateInvestorContributionByPresalePhase(address _account, uint256 _weiAmount, uint256 _tokenAmount) private{
        if(isPhase1Active){
            unchecked {
                totalPersonalTokenInvestmentPhase1[_account] += _tokenAmount; 
                totalPersonalWeiInvestmentPhase1[_account] += _weiAmount;
            }
        }else if(isPhase2Active){
            unchecked {
                totalPersonalTokenInvestmentPhase2[_account] += _tokenAmount; 
                totalPersonalWeiInvestmentPhase2[_account] += _weiAmount; 
            }
        }else{
            unchecked {
                totalPersonalTokenInvestmentPhase3[_account] += _tokenAmount;
                totalPersonalWeiInvestmentPhase3[_account] += _weiAmount;
            }
        }
    }

    function _updateInvestorContributionAfterClaims(uint256 _tokenAmount) private{
        unchecked{
            totalTokenContributionsClaimedByUser[msg.sender] += _tokenAmount;
            totalTokensClaimed += _tokenAmount;
        }
    }

    function _checkDurations() private{
        if(block.timestamp > phase1End && block.timestamp <= phase2Start){
            _activatePhase2();
        }else if(block.timestamp > phase2End && block.timestamp <= phase3Start){
             _activatePhase3();
        }else if(block.timestamp > phase3End){
            _setPresaleClosed();
        }

        if(totalTokensSold > phase1TotalTokensToSell && isPhase1Active){
            _activatePhase2();
        }else if(totalTokensSold > phase1TotalTokensToSell + phase2TotalTokensToSell && isPhase2Active){
            _activatePhase3();
        }else if(totalTokensSold > maxTokenCapForPresale){
            _setPresaleClosed();
        }
    }
}