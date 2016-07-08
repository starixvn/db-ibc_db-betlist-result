USE bodb02
GO

ALTER PROCEDURE [dbo].[Age_BetList_SelWinlossOutright_Ag]
	@CustID			INT				= NULL, --superID
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@leagueID		INT				= NULL,
	@Language		VARCHAR(2)		= 'E',
	@MoveBetsDay	SMALLDATETIME
AS

/*
	Created:
	Task : get bet tickets for outright, horse racing
	DB: DB05.bodb02
	Original: 

	Revisions:    
		- 20090407@[HanhVu]: remove redundant transid field
		- 20090421@[HiepVo]: Include more columns: comm, acomm, scomm, awinlost, mwinlost, swinlost
		- 20090505@HiepVo: Change formula of commission
		- 20090618@AnhPham: Remove 'Customer' table
		- 20090710@Phuc: unhide IP for TB currency.
		- 20101007@Henry: Change column transid from INT to BIGINT
		- 20101224@Johnson: change type of bettype to SMALLINT in temporary table
		- 20111216@Sophia: Remove function f_GetOddsByBettype , f_GetChoice , f_ShowOddsByBettype
		- 20120927@Sophia: Get comstatus
		- 20150420@Tom: Add @leagueID parameter
		- 20151203@Kos: Change odds, modds data type from SMALLMONEY to MONEY [Redmine: #48660]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @AgWinlossOutright TABLE(
		sporttype SMALLINT,
		username NVARCHAR(30),
		bettype SMALLINT,			
		transid BIGINT,
		matchcode VARCHAR(30),
		homeID INT,
		awayID INT,
		hdp1 SMALLMONEY,
		hdp2 SMALLMONEY,
		odds MONEY,
		status NVARCHAR(10),
		stake MONEY,
		winlost MONEY,
		awinlost MONEY,
		mwinlost MONEY,
		swinlost MONEY,
		playercomm MONEY,
		comm MONEY,
		acomm MONEY,
		scomm MONEY,
		transdate DATETIME,
		betteam NVARCHAR(25),
		apositiontaking SMALLMONEY,		
		adiscount SMALLMONEY,		
		liveindicator BIT,
		livehomescore SMALLINT,
		liveawayscore SMALLINT,
		leagueID INT,
		matchid INT, 
		IP VARCHAR(20),
		betstatus VARCHAR(20),
		isNeutral BIT,
		comstatus NVARCHAR(20)
	)

	IF @Todate > @MoveBetsDay
	BEGIN
		INSERT INTO @AgWinlossOutright 
		SELECT
			l.sporttype,
			b.username,
			b.bettype,
			b.transid,
			m.matchcode,
			m.teamID,
			0,
			b.hdp1,
			b.hdp2,
			b.odds,
			b.status,
			b.stake,
			(b.winlost-actual_stake),
			b.awinlost,
			b.mwinlost,
			b.swinlost,
			b.playercomm,
			(b.comm - b.playercomm) AS comm,
			(b.acomm - b.comm) AS acomm ,
			(b.scomm - b.acomm) AS scomm,
			b.transdate,
			b.betteam,
			b.apositiontaking,		
			b.discount AS adiscount,		
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			l.leagueID,
			b.matchid, 
			b.IP AS IP,
			NULL,
			CONVERT(BIT,0) AS IsNeutral,
			CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus
		FROM
			bettrans b WITH (NOLOCK) 
			INNER JOIN outright m WITH (NOLOCK) ON b.matchid=m.orid	
			INNER JOIN League l WITH (NOLOCK) ON m.leagueID=l.leagueID		
		WHERE
			b.Recommend=@CustID AND
			b.Winlostdate>=@FromDate AND
			b.Winlostdate<=@ToDate AND
			b.Bettype=10 AND
			b.Ruben=1 AND
			(@leagueID IS NULL OR m.leagueID = @leagueID)
	END

	IF @Fromdate <= @MoveBetsDay
	BEGIN
		INSERT INTO @AgWinlossOutright SELECT
			l.sporttype,
			b.username,
			b.bettype,
			b.transid,
			m.matchcode,
			m.teamID,
			0,
			b.hdp1,
			b.hdp2,
			b.odds,
			b.status,
			b.stake,
			(b.winlost-actual_stake),
			b.awinlost,
			b.mwinlost,
			b.swinlost,
			b.playercomm,
			(b.comm - b.playercomm) AS comm,
			(b.acomm - b.comm) AS acomm ,
			(b.scomm - b.acomm) AS scomm,
			b.transdate,
			b.betteam,
			b.apositiontaking,		
			b.discount AS adiscount,		
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			l.leagueID,
			b.matchid, 
			b.IP AS IP,
			NULL,
			CONVERT(BIT,0) AS IsNeutral,
			CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus
		FROM
			bettrans14 b WITH (NOLOCK) 
			INNER JOIN outright14 m WITH (NOLOCK) ON b.matchid=m.orid	
			INNER JOIN League l WITH (NOLOCK) ON m.leagueID=l.leagueID
		WHERE
			b.Recommend=@CustID AND
			b.Winlostdate>=@FromDate AND
			b.Winlostdate<=@ToDate AND
			b.Bettype=10 AND
			b.Ruben=1	AND
			(@leagueID IS NULL OR m.leagueID = @leagueID)
	END

	SELECT * FROM @AgWinlossOutright 
	ORDER BY Status, Transid
END
		

GO
GRANT EXECUTE ON [dbo].[Age_BetList_SelWinlossOutright_Ag] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_BetList_SelWinlossOutright_Ag] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_BetList_SelWinlossOutright_Ag] TO [VNTeam]