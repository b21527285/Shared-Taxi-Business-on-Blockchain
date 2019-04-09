pragma solidity ^0.5.0;
contract TaxiBusiness {

    int profit;
    uint quota;
    uint fixedExpenses = 10 ether;
    uint participationFee;

    mapping(address => Participant) participants;
    address[] addresses;
    uint participantCount;

    address manager;
    address payable taxiDriver;
    uint taxiDriverSalary;
    uint taxiDriverBal;
    address payable carDealer;

    uint32 ownedCar;
    Proposal proposedCar;
    Proposal proposedPurchase;

    //Time handles
    uint nextPayDay;
    uint nextExpenseDay;
    uint nextProfitDay;

    event LogUserJoined(address user,uint count);
    event LogLog(string log);
    event LogLog2(string log, uint n);
    
    struct Proposal{
        uint32 carID;
        uint price;
        uint validUntil;
        uint approvalState;
        bool accepted;
    }

    struct Participant {
        address payable adr;
        uint balance;
        bool voted;
    }

    constructor() public { //Called by owner of the contract and sets the manager and other initial values for state variables
        participantCount = 0;
        manager = msg.sender;
        quota = 100;
        participationFee = 10 wei;
        taxiDriverSalary = 5 wei;
    }

    /* Called by participants, Participants needs to pay the participation fee set in the contract to be a
    member in the taxi investment */
    function join() payable public {
        require(msg.value==participationFee && participantCount<quota);
        require (participants[msg.sender].adr == address(0) && msg.sender!=carDealer);
        // car dealer is not allowed to join
        participants[msg.sender] = Participant({
            adr: msg.sender,
            balance: 0,
            voted: false
        });
        addresses.push(msg.sender);
        participantCount++;
        profit += int(participationFee);
        emit LogUserJoined(msg.sender,participantCount);
    }

    // Only Manager can call this function, Sets the CarDealer’s address
    function setCarDealer(address payable carDealerAddress) public{
        require(msg.sender==manager && participants[carDealerAddress].adr==address(0));
        carDealer = carDealerAddress;
    }

    // Only CarDealer can call this, sets Proposed Car values, such as CarID, price, and offer valid time
    function carPropose(uint32 carID,uint price, uint validUntil) public {
        require(msg.sender == carDealer);
        proposedCar = Proposal({
            carID: carID,
            price:price,
            validUntil:validUntil,
            approvalState:0,
            accepted: false
        });
    }

    /* Only Manager can call this function, sends the CarDealer the price of the proposed car if the offer valid
    time is not passed yet. */
    function purchaseCar() public {
        require(msg.sender==manager);
        require(now<=proposedCar.validUntil && address(this).balance<proposedCar.price && proposedCar.accepted==false);
        proposedCar.accepted=true;
        carDealer.transfer(proposedCar.price);
        ownedCar = proposedCar.carID;
        profit-=int(proposedCar.price);
        nextExpenseDay =now+15552000;
    }
    
    /* Only CarDealer can call this, sets Proposed Purchase values, such as CarID, price, offer valid time and
    approval state (to 0) */
    function proposePurchase(uint32 carID,uint price, uint validUntil) public {
        require (msg.sender == carDealer);
        proposedPurchase = Proposal({
            carID: carID,
            price:price,
            validUntil:validUntil,
            approvalState:0,
            accepted: false
        });
        for (uint i=0;i<participantCount;i++){
                participants[addresses[i]].voted = false;
        }
    }

    /* Participants can call this function, approves the Proposed Purchase with incrementing the approval
    state. Each participant can increment once. */
    function approveSellProposal() public {
        Participant storage p = participants[msg.sender];
        require (p.adr==address(0) && p.voted == false);
        p.voted=true;
        proposedPurchase.approvalState++;
    }

    /* Only CarDealer can call this function, sends the proposed car price to contract if the offer valid time is
    not passed yet and approval state is approved by more than half of the participants. */
    function sellCar() payable public {
        require(proposedPurchase.approvalState>=participantCount/2);
        require(msg.sender == carDealer && msg.value == proposedPurchase.price && now<=proposedPurchase.validUntil && proposedPurchase.accepted==false);
        
        proposedPurchase.accepted = true;
        ownedCar = uint32(0);
        profit+=int(proposedPurchase.price);

    }

    // Only Manager can call this function, sets the Driver info
    function setDriver(address payable driverAdr) public {
        require (msg.sender == manager);
        taxiDriver = driverAdr;
        nextPayDay = now+2592000;
    }

    /* Public, customers who use the taxi pays their ticket through this function. Charge is sent to contract.
    Takes no parameter. See slides 6 page 11. */
    function getCharge() payable public {
    }

    /* Only Manager can call this function, releases the salary of the Driver to his/her account monthly. Make
    sure Manager is not calling this funciton more than once in a month. */
    function paySalary() public {
        require (msg.sender == manager && now>=nextPayDay && taxiDriver>address(0));
        nextPayDay+=2592000; //a month
        taxiDriverBal+=taxiDriverSalary;
        profit-=int(taxiDriverSalary);
    }

    /* Only Driver can call this function, if there is any money in Driver’s account, it will be send to his/her
    address */
    function getSalary() public {
        require (msg.sender == taxiDriver);
        taxiDriverBal=0;
        taxiDriver.transfer(taxiDriverBal);
    }
    
    /* Only Manager can call this function, sends the CarDealer the price of the expenses every 6 month.
    Make sure Manager is not calling this function more than once in the last 6 months. */
    function carExpenses() public {
        require (msg.sender == manager && now>=nextExpenseDay && carDealer>address(0));
        nextExpenseDay+=15552000; // 6 months
        carDealer.transfer(fixedExpenses);
        profit-=int(fixedExpenses);
    }

    /* Only Manager can call this function, calculates the total profit after expenses and Driver salaries,
    calculates the profit per participant and releases this amount to participants in every 6 month. Make sure
    Manager is not calling this function more than once in the last 6 months. */
    function payDividend() public {
        require (msg.sender == manager && now>=nextProfitDay);
        if (taxiDriver>address(0)){ // pay the driver and car dealer first
            require(now < nextPayDay);
        }
        if (ownedCar > uint32(0)){
            require(now < nextExpenseDay);
        }
        nextProfitDay += 15552000;
        int perParticipant = profit/int(participantCount); // e.g. profit = 10; participantcount = 3; thus temp = 3;
        int total = perParticipant * int(participantCount); // total = 9 (3 per participant);
        
        if (total>0){ 
            profit -= total;  // profit = 1 left;
            for (uint i=0;i<participantCount;i++){
                participants[addresses[i]].balance+=uint(perParticipant);
                //profit-=perParticipant;
            }
        }
    }

    // Only Participants
    function getDividend() public {
        if (participants[msg.sender].adr>address(0)){
            participants[msg.sender].balance = 0;
            msg.sender.transfer(participants[msg.sender].balance);
        }
    }

}
