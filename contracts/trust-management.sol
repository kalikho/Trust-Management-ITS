//pragma solidity ^0.4.21;
pragma solidity ^0.5.16;

contract TrustManagement {

/** Vehicle Structure **/    
struct Vehicle_Register{
        int TV;
        uint256 credit_score;
        address acno;
        bool Revoked;
        bool is_VEH_intelligent;
        uint claimed;
        uint claim_limit;
        uint time;
}

/** RSU - Road Side Unit Structure **/
struct RSU{
        address RSUId;
        string name;
        uint256 s_uid;
        uint256 reg_v_id;
}

/** Personal Transaction Register specific
to each particular Vehicle **/
struct Personal_Transaction_Register{
        bool submitted;
        bool isrewardReceived;
}    

struct Score_Status_Register{
        uint score;
        bool verificationStatus;
}

struct Session_Register{
    uint count;
    address registered_address;
    address alarmer;
    bool enrolled;    
}

struct Vehicles_in_Session_Register{
    address registered_address;
    address doubty_vehicle;
}

struct Claimable_Reward{
    address session;
    address suspected_vehicle;
}

/** Contract Deployer is the Traffic Authority **/
address TAaddress = msg.sender;

uint pid = 0;
uint256 oti = 0;
uint256 TA_Round = 0;

 
address[] Vehicleaddress;
address[] RoadSideUnits;
address[] RevocationList;
address[] RegisteredSession;

mapping(address => mapping(address => mapping(address => Personal_Transaction_Register))) PTR;
mapping(address => mapping(address => Score_Status_Register)) SSR;

mapping(address => mapping(uint256 => Vehicles_in_Session_Register)) VISR;
mapping (address => Vehicle_Register) VR;
mapping (address => RSU) rsu;
mapping (address => Session_Register) SESSION_REGISTER;
mapping (uint => Claimable_Reward) CR;

modifier OnlyRSU{
    bool flag = false;
    for(uint i=0;i<RoadSideUnits.length;i++){
       if(msg.sender == RoadSideUnits[i]){
           flag = true;
       }
    }
    require(flag == true,"You are not a RSU");
    _;
}
modifier OnlyTA{
    bool auth = false;
    if(msg.sender == TAaddress){
        auth = true;
    }
        require(auth == true,"You are not the Traffic Authority");
        _;
}
modifier NotRevoked(address _acno){
    bool statusRevocation = false;
    for(uint i=0;i<RevocationList.length;i++){
            if(RevocationList[i] == _acno){
                statusRevocation = true;
            }
        }
        require(statusRevocation == false,"Your vehicle is Revoked");
        _;
}
modifier IntelligentVehicle(address _acno){
    bool is_VEH_intelligent = false;
        if(VR[_acno].acno == _acno){
            is_VEH_intelligent = true;
        }
        require(is_VEH_intelligent == true,"You are not an Intelligent Vehicle");
        _;
}

modifier New_Event(){
    bool flag = false;
    if(TA_Round < RegisteredSession.length){
        flag = true;
    }
    require(flag == true,"No suspision reported");
    _;
}

modifier IsBlocked(address suspected_vehicle){
    bool flag = false;
    if(VR[suspected_vehicle].time > now){
        flag = true;
    }
    require(flag == false,"You are blocked for 1 minute");
    _;
}

/** Vehicle Registration, Only performed by the TA **/
function configureVEH(address _acno) OnlyTA public {
        VR[_acno].acno = _acno;
        VR[_acno].TV = 10;
        VR[_acno].credit_score = 100;
        VR[_acno].Revoked = false;
        VR[_acno].claim_limit = 0;
        VR[_acno].claimed = 0;
        VR[_acno].time = now;
}

function reportMisbehaviour(address session, address suspected_vehicle) IntelligentVehicle(msg.sender) IntelligentVehicle(suspected_vehicle) NotRevoked(msg.sender) IsBlocked(msg.sender) public  {
        if(SESSION_REGISTER[session].enrolled != true){
            RegisteredSession.push(session) -1;
            SESSION_REGISTER[session].alarmer = msg.sender;
            SESSION_REGISTER[session].enrolled = true;
        }
        
        SESSION_REGISTER[session].count = SESSION_REGISTER[session].count + 1;
        VISR[session][SESSION_REGISTER[session].count].registered_address = msg.sender;
        VISR[session][SESSION_REGISTER[session].count].doubty_vehicle = suspected_vehicle;
    
        if(PTR[msg.sender][session][suspected_vehicle].submitted == false){
            SSR[session][suspected_vehicle].score = SSR[session][suspected_vehicle].score + 1;
            PTR[msg.sender][session][suspected_vehicle].submitted = true;
            PTR[msg.sender][session][suspected_vehicle].isrewardReceived = false;
            CR[VR[msg.sender].claim_limit].session = session;
            CR[VR[msg.sender].claim_limit].suspected_vehicle = suspected_vehicle;
            VR[msg.sender].claim_limit = VR[msg.sender].claim_limit + 1;
        }else{
            revert();
        }
}

function TACheck() OnlyTA New_Event()  public {
    address session = RegisteredSession[TA_Round];
    for(uint i=1;i<=SESSION_REGISTER[session].count;i++){
        address suspected_vehicle = VISR[session][i].doubty_vehicle;
        oti = oti + 1;
        if(SSR[session][suspected_vehicle].score > SESSION_REGISTER[session].count/2){
           pid = pid + 1;
            VR[suspected_vehicle].TV = VR[suspected_vehicle].TV - 1;
            VR[suspected_vehicle].time = VR[suspected_vehicle].time + 1 minutes;
                if(VR[suspected_vehicle].TV < 0 && VR[suspected_vehicle].Revoked == false){
                    RevocationList.push(suspected_vehicle) - 1;
                    VR[suspected_vehicle].Revoked = true;
                    
                }
            SSR[session][suspected_vehicle].verificationStatus = true;
        }
    }
     TA_Round = TA_Round + 1;
}

function claimReward() public {
    
    address session = CR[VR[msg.sender].claimed].session;
    address suspected_vehicle = CR[VR[msg.sender].claimed].suspected_vehicle;
    
    if(PTR[msg.sender][session][suspected_vehicle].isrewardReceived == false){
        if(SSR[session][suspected_vehicle].verificationStatus == true){
            if(SSR[session][suspected_vehicle].verificationStatus == PTR[msg.sender][session][suspected_vehicle].submitted){
                VR[msg.sender].credit_score = VR[msg.sender].credit_score + 5;
                VR[msg.sender].claimed = VR[msg.sender].claimed + 1;
                if(SESSION_REGISTER[session].alarmer == msg.sender){
                    VR[msg.sender].credit_score = VR[msg.sender].credit_score + 2;
                }
                PTR[msg.sender][session][suspected_vehicle].isrewardReceived = true;
            }
        }
    }else{
        revert();
    }
}

function releasePayment(address payable acno) OnlyTA public payable {
             uint256 vehicle_credit = VR[acno].credit_score;
             uint256 amount = vehicle_credit * 2;
             assert(msg.value == amount);
             if(msg.value != amount){
               revert();
              }         
              VR[acno].credit_score = 0;
              acno.transfer(msg.value);
}


function RevokedVehicles() view public returns(address[] memory){
        return RevocationList;
}
function dummyCheck(address session) view public returns (uint,uint,uint){
    return (SESSION_REGISTER[session].count,oti,pid);
}

function checkmyTVC() view public returns(int,uint){
    return(VR[msg.sender].TV,VR[msg.sender].credit_score);
}

function CheckmyClaims() view public returns(string memory){
    if(VR[msg.sender].claimed == VR[msg.sender].claim_limit){
        return("No more pending Claims");
    }

    if(SSR[CR[VR[msg.sender].claimed].session][CR[VR[msg.sender].claimed].suspected_vehicle].verificationStatus != true){
        return("Claim not yet verified by TA");
    }
     else{
         return("You have got pending Claims.- Check Pending Claim Details for more info");
     }
    
}

function MoreInfoOnClaims() view public returns(string memory,address,address){
    return("Latest Pending Claim Info",CR[VR[msg.sender].claimed].session,CR[VR[msg.sender].claimed].suspected_vehicle);
}

function Reevaluation(address session,address suspected_vehicle) view public returns (uint, uint){
    return(SSR[session][suspected_vehicle].score,SESSION_REGISTER[session].count/2);
}

function checkengeth() view public returns(uint){
    return RegisteredSession.length;
}
function checkScore(address session,address suspected_vehicle) view public returns (uint){
    return (SSR[session][suspected_vehicle].score + 1);
}

function TAC() view public returns(address){
    return (RegisteredSession[0]);
}

}


