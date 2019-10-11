/*<info serverAlias="DBEXT-bodb02" executers="bodbAdminNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Acc_BA_MonitorBetList]
  @TotalRow INT,
  @Amount INT = 0,
  @LastTransId BIGINT = 0
 /*
	Created: Johnson
	DB: DB052.BODB02
	Date: 2011-06-14
	Task: BA Monitor Bets 
		
	Revision:
		- 20110808@Henry: add param @LastTransId
	Param's Explanation:
	+	@TotalRow: Total rows the SP will return
	+	@Amount: to constrainst the stake, stake should greater than or equal to param amount
	+	@LastTransId: return from lastTransId forward, default is 0
 */
 AS
	SET NOCOUNT ON
	
	DECLARE @tmpBetList TABLE(		
		bettype		INT,
		transid		BIGINT, 
		betid		BIGINT,
		refno		NVARCHAR(50), 
		matchcode	NVARCHAR(50),
		homeid		INT, 
		awayid		INT, 
		hdp1		SMALLMONEY, 
		hdp2		SMALLMONEY, 
		odds		SMALLMONEY,
		OddsType	TINYINT,
		status		NVARCHAR(50), 
		Stake MONEY, 
		Actual_Stake	MONEY,
		transdate	DATETIME,
		betteam		NVARCHAR(10),
		liveindicator	BIT,
		modds			SMALLMONEY,
		custid			INT,
		livehomescore	INT, 
		liveawayscore	INT, 
		leagueid		INT, 
		sporttype		SMALLINT, 
		matchid			INT,
		isNeutral		BIT,
		CurrencyName	NVARCHAR(50),
		UserName		NVARCHAR(50)
 )
 
	--Single bet
	INSERT INTO @TmpBetList
	SELECT 
		b.bettype,
		b.transid,
		ISNULL(b.betid,0),
		b.refno,
		m.matchcode,
		m.homeid,
		m.awayid,
		b.hdp1,
		b.hdp2,		
		b.odds,
		b.oddstype,
		b.status,
		b.stake,
		b.actual_stake, 
		b.transdate,
		b.betteam,
		b.liveindicator,
		b.modds,
		b.custid,
		b.livehomescore,
		b.liveawayscore,
		m.leagueid,
		m.sporttype,
		b.matchid,
		m.IsNeutral,
		b.CurrencyName,
		b.UserName
	FROM bettrans b WITH (NOLOCK)
		INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction ba WITH(NOLOCK)  ON ba.transid = b.transid  
		INNER JOIN MATCH m WITH(NOLOCK) ON b.matchid = m.matchid
	WHERE b.statusID IN (0,1)
	
	--Mixparlay
	INSERT INTO @tmpBetList
	SELECT 
		9 AS bettype,
		b.transid,
		ISNULL(b.betid,0),
		b.refno,
		'' matchcode,
		0 AS homeid,
		0 AS awayid,
		b.hdp1,
		b.hdp2,		
		b.odds,
		b.oddstype,  
		b.status,
		b.stake,
		b.actual_stake, 
		b.transdate,
		b.betteam,
		b.liveindicator,
		b.modds,
		b.custid,
		0 AS livehomescore,
		0 AS liveawayscore,
		0 AS leagueid,
		0 AS sporttype,
		9 AS matchid,
		CONVERT(BIT,0) IsNeutral,
		b.CurrencyName,
		b.UserName
		
	FROM bodb_Licensee.dbo.LicenseeBATransaction ba WITH(NOLOCK)  
		INNER JOIN dbo.bettrans b WITH(NOLOCK) ON ba.TransID = b.transid
	WHERE b.statusID IN( 0,1)
		AND b.bettype = 9
		AND b.matchid = 9
		
	--Combination Mixed Parlay
	INSERT INTO @tmpBetList
	SELECT 
		29 AS bettype,
		b.transid,
		ISNULL(b.betid,0),
		b.refno,
		'' matchcode,
		0 AS homeid,
		0 AS awayid,
		b.hdp1,
		b.hdp2,		
		b.odds,
		b.oddstype,  
		b.status,
		b.stake,
		b.actual_stake, 
		b.transdate,
		b.betteam,
		b.liveindicator,
		b.modds,
		b.custid,
		0 AS livehomescore,
		0 AS liveawayscore,
		0 AS leagueid,
		0 AS sporttype,
		9 AS matchid,
		CONVERT(BIT,0) IsNeutral,
		b.CurrencyName,
		b.UserName
		
	FROM bodb_Licensee.dbo.LicenseeBATransaction ba WITH(NOLOCK)  
		INNER JOIN dbo.bettrans b WITH(NOLOCK) ON ba.TransID = b.transid
	WHERE b.statusID IN( 0,1)
		AND b.bettype = 29	
		AND b.matchid = 29
	
	--Outright	
	INSERT INTO @tmpBetList
	SELECT 
		b.bettype,
		b.transid,
		ISNULL(b.betid,0),
		b.refno,
		m.matchcode,
		0 AS homeid,
		m.teamid AS awayid,
		b.hdp1,
		b.hdp2,
		b.odds,
		'' OddsType,  
		b.status,
		b.stake,
		b.actual_stake, 
		b.transdate,
		b.betteam,
		b.liveindicator,
		b.modds,
		b.custid,
		b.livehomescore,
		b.liveawayscore,
		m.leagueid,
		l.sporttype,
		b.matchid,
		CONVERT(BIT, 0) IsNeutral,
		b.CurrencyName,
		b.UserName
		
	FROM bodb_Licensee.dbo.LicenseeBATransaction ba WITH(NOLOCK)   
		INNER JOIN dbo.bettrans b WITH(NOLOCK) ON ba.TransID = b.transid
		INNER JOIN dbo.outright m WITH(NOLOCK) ON b.matchid = m.orid
		INNER JOIN dbo.league l WITH(NOLOCK) ON m.leagueid = l.leagueid		
	WHERE b.statusID IN (0,1)	
		AND b.bettype = 10
	
	--Update Betteam, odds and oddstype	
	UPDATE @tmpBetList
	SET betteam = dbo.f_GetChoice(betteam,bettype,'E')
	WHERE bettype IN (14,16)
		
	UPDATE @tmpBetList
	SET odds = CASE WHEN OddsType = 1 THEN odds + 1
					WHEN OddsType = 5 THEN odds * 100
					ELSE odds END		
	WHERE bettype IN (1,2,3,7,12,8,20)	
	
	UPDATE @tmpBetList
	SET OddsType = 0 
	WHERE bettype NOT IN (1,2,3,7,12,8,20)
	
	
	SELECT TOP (@TotalRow) * FROM @TmpBetList
	WHERE 
		stake >= @Amount
		AND transid > @LastTransId
	ORDER BY transid DESC




GRANT EXECUTE ON [dbo].[Acc_BA_MonitorBetList] TO bodbAdminNet
GO
