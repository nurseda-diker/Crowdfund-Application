// SPDX-License-Identifier:MIT

pragma solidity ^0.8.13;
import "/.IERC20.sol";

contract Crowdfund{
    event Launch(
        uint id,
        address indexed creator,
        uint goal,
        uint32 startAt,
        uint32 endAt
    );

    event Cancel(uint id);
    //indexed sebebi bu kamoanya adresine birçok kişi rehin verebilecek
    event Pledge(uint indexed id,address indexed caller,uint amount);
    event Unpledge(uint indexed id,address indexed caller,uint amount);
    event Claim(uint id);
    event Refund(uint indexed id,address indexed caller,uint amount);

    struct Campaign{
        address creator;
        uint _goal;
        uint pledged;
        uint _startAt;
        uint _endAt;
        bool claimed;
    }

    IERC20 public immutable token;  //değişmez
    uint public count;
    mapping(uint => Campaign) public campaigns;
    mapping(uint => mapping(address => uint)) public pledgedAmount;


    function launch(uint _goal,uint _startAt,uint _endAt) external{

        require(_startAt >= block.timestamp,"start at < now");
        require(_endAt >= _startAt,"end at < start at");
        require(_endAt <= block.timestamp + 90 days,"end at > max duration");

        count += 1;
        campaigns[count] = Campaign({
            creator : msg.sender,
            goal:_goal,
            pledged:0,
            startAt:_startAt,
            endAt:_endAt,
            claimed:false
        });
        emit Launch(count,msg.sender,_goal,_startAt,_endAt);
    
    }

    //kampanyayı oluşturan kişi kampanya henüz başlamadıysa kampanyayı iptal edebilir.
    //eğer birisi yanlışıkla kampanya oluşturursa bu fonksiyon ile iptal edilebilir.
    function cancel(uint _id) external{
         Campaign memory campaign=campaigns[_id];
         require(msg.sender == campaign.creator,"not created");
         require(block.timestamp < campaign.startAt,"started");
         delete campaigns(_id);
         emit Cancel(_id);
    }

    function pledge(uint _id,uint _amount) external{
        Campaign storage campaign = campaigns[_id];
        require(block.timestamp >= campaign.startAt,"not started");
        require(block.timestamp <= campaign.endAt,"ended");

        campaign.pledged += _amount;
        pledgedAmount[_id][msg.sender] += _amount;
        token.transferFrom(msg.sender,address(this),_amount);

        emit Pledge(_id,msg.sender,_amount);
    }
    
    function unpledge(uint _id,uint _amount) external{
        Campaign storage campaign = campaigns[_id];
        //kullanıcılar sona eren bir kampanyadan taahhüdünü geri almamalıdır
        require(block.timestamp <= campaign.endAt,"ended");

        campaign.pledged -= _amount;
        pledgedAmount[_id][msg.sender] -= _amount;
        token.transfer(msg.sender,_amount);

        emit Unpledge(_id,msg.sender,_amount);


    }

    function claim(uint _id) external{
        Campaign storage campaign = campaigns[_id];
        require(msg.sender == campaign.creator,"not creator");
        require(block.timestamp > campaign.endAt,"not ended");
        require(campaign.pledged >= campaign.goal,"pledged < goal");
        require(!campaign.claimed,"claimed");

        campaign.claimed = true;
        token.transfer(msg.sender,campaign.pledged);
        emit Claim(_id);
    }

    //kampanya başarısız olursa kullanıcılar geri ödeme alabilir
    function refund(uint _id) external{
        Campaign storage campaign = campaigns[_id];
        require(block.timestamp > campaign.endAt,"not ended");
        require(campaign.pledged >= campaign.goal,"pledged < goal");

        uint bal = pledgedAmount[_id][msg.sender];
        //belirteci yeniden transfer etmeden önce bakiyeyi sıfırlamamızın nedeni tüm belirteçler iade edildikten sonra yeniden giriş etkisini önlemek
        pledgedAmount[_id][msg.sender]=0;
        token.transfer(msg.sender,bal);

        emit Refund(uint _id,msg.sender,bal);


    }



}
