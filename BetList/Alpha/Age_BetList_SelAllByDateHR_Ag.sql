
ALTER PROCEDURE [dbo].[Age_BetList_SelAllByDateHR_Ag]
	 @CustID int=null, --AgentID  
	 @Bettype int,    	 
	 @MatchID int,
	 @Language varchar(2) = 'E' 
AS 

/*
Created: 
Task : get Horse Racing tickets for Agent level
DB: DB053.bodb02
Original 
Revisions:    
    - 20090406@HanhVu: - remove refno
    - 20090421@[HiepVo]: Include more columns: comm, acomm, scomm, awinlost, mwinlost, swinlost 
    - 20090505@HiepVo: Change formula of commission		
    - 20090529@HiepVo:  Get more data from bettransm for HR			   
    - 20090618@AnhPham: Remove 'Customer' table
    - 20091024@[MinhNguyen]: get modds, finalodds.
    - 20091028@AnhPham: remove unnecessary values concern to winlost, commission, PT, discount of upline
	- 20110307@Lukas: get more sporttype (152, 153)
	- 20110602@Amy: add more condition to get ticket details for WIN/PLACE (33)
	- 20120313@Lukas: Modify winlostdate condition to get Aust racing tickets ( cross-date meetings)
	- 20120927@Sophia: Get comstatus
*/
 
SET NOCOUNT ON  

Declare @FromDate datetime, @ToDate datetime
Select @ToDate = convert(datetime,convert(nvarchar(20), getdate(), 101))
Select	@FromDate = dateadd(dd,-1,@ToDate),
		@Todate = dateadd(dd,1,@Todate)
 
SELECT
    b.UserName,
	l.sporttype,
	b.bettype,		
	b.transid,
	m.matchcode,
	b.matchid,
	m.GroupMatch as Race,
	m.teamID as homeID,
	0 as awayID,
	b.hdp1, 
	b.hdp2,
	modds,
	b.odds,
	b.status,
	b.stake,
	(winlost-actual_stake)  winlost,
	b.awinlost,
	0 as mwinlost,
	0 as swinlost,
	(playercomm) AS playercomm,
	(b.comm - b.playercomm) as comm,
	0 as acomm,
	0 as scomm,
	
	b.transdate,
	b.winlostdate,
	'' as Betteam,    
	b.apositiontaking,	
	0 as mpositiontaking,
	0 as spositiontaking,
	
	b.discount as adiscount,
	0 as mdiscount,
	0 as sdiscount,
	
	m.leagueID,
	0 as liveindicator , 
	b.livehomescore, 
	b.liveawayscore,
	b.IP, 
	'' betstatus,
	CONVERT(BIT,0) as IsNeutral,
	CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus
 FROM  
  bettrans b with (nolock)
  inner join outright m with (nolock) on b.matchid=m.orid   
  inner join League l with (nolock) on m.leagueID=l.leagueID    
 WHERE  
  b.Recommend=@CustID
  AND m.eventdate BETWEEN @FromDate AND @ToDate
  AND b.MatchId= @MatchID
  AND b.Bettype= @Bettype  

IF @Bettype = 33 OR @Bettype = 43
BEGIN
	--get data from bettransm for bettype 33,43
	SELECT 
		BM.refno, 
		BM.finalodds,
		BM.odds, 
		BM.status, 
		BM.apositiontaking, 
		0 as mpositiontaking, 
		0 as spositiontaking,
		BM.bettype  
	FROM bettransm BM with (NOLOCK)
	INNER JOIN bettrans B with (NOLOCK) ON BM.refno = B.transid
	WHERE B.Bettype = @Bettype AND B.MatchId= @MatchID AND B.Recommend=@CustID

END


GO
GRANT EXECUTE ON [dbo].[Age_BetList_SelAllByDateHR_Ag] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_BetList_SelAllByDateHR_Ag] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_BetList_SelAllByDateHR_Ag] TO [vnteam]
