ALTER PROCEDURE [dbo].[Age_BetList_SelWinlossHR_Ag]
	@CustID			INT				= NULL, -- AgentID
	@Bettype		INT,
	@LeagueId		INT,
	@Race			VARCHAR(20),
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@Language		VARCHAR(2)		= 'E',
	@MoveBetsDay	SMALLDATETIME
AS

/*
	Created:
	Task: Betlist
	DB: DBAGE.bodb02
	Original:
	Revisions:
		- 20090407@[HanhVu]:- remove refno
		- 20090421@[HiepVo]: Include more columns: comm, acomm, scomm, awinlost, mwinlost, swinlost
		- 20090505@HiepVo: Change formula of commission
		- 20090530@HiepVo:  Get more data from bettransm for HR
		- 20090618@AnhPham: Remove 'Customer' table
		- 20090710@Phuc: unhide IP for TB currency.
		- 20091024@[MinhNguyen]: get modds, finalodds.
		- 20101007@Henry: Change column transid from INT to BIGINT
		- 20101224@Johnson: change type of bettype to SMALLINT in temporary table
		- 20120927@Sophia: Get comstatus
		- 20130306@Elodie: Add bet list of Virtual HR
		- 20151203@Kos: Change odds, modds data type from SMALLMONEY to MONEY [Redmine: #48660]
		- 20161010@Kos: Add product bet type range for sub tickets [Redmine: #65045]
*/

BEGIN
	SET NOCOUNT ON

	-- Get Sport Bettype Matrix (support Horse Racing, Virtual Horse Racing only)
	DECLARE @SportBettype TABLE(ProductId TINYINT, Bettype SMALLINT, EventType TINYINT)

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype
	SELECT ProductID, BetType, EventType
	FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest)
	WHERE ProductID = 2
		OR (ProductID = 5 AND EventType = 3)

	DECLARE @AgWinlossHR TABLE (
		SportType		SMALLINT,
		Username		NVARCHAR(30),
		CustId			INT,
		BetType			SMALLINT,
		TransId			BIGINT,
		Race			VARCHAR(20),
		MatchCode		VARCHAR(30),
		HomeId			INT,
		AwayId			INT,
		Hdp1			SMALLMONEY,
		Hdp2			SMALLMONEY,
		Modds			MONEY,
		Odds			MONEY,
		Status			NVARCHAR(10),
		Stake			MONEY,
		WinLost			MONEY,
		AWinLost		MONEY,
		MWinLost		MONEY,
		SWinLost		MONEY,
		PlayerComm		MONEY,
		Comm			MONEY,
		AComm			MONEY,
		SComm			MONEY,
		TransDate		DATETIME,
		BetTeam			NVARCHAR(25),
		APositionTaking	SMALLMONEY,
		MPositionTaking	SMALLMONEY,
		SPositionTaking	SMALLMONEY,
		ADiscount		SMALLMONEY,
		MDiscount		SMALLMONEY,
		SDiscount		SMALLMONEY,
		LiveIndicator	BIT,
		LiveHomeScore	SMALLINT,
		LiveAwayScore	SMALLINT,
		LeagueId		INT,
		MatchId			INT,
		Ip				VARCHAR(20),
		BetStatus		VARCHAR(20),
		IsNeutral		BIT,
		ComStatus		NVARCHAR(20),
		RefNo			NVARCHAR(50),
		ShowTime		NVARCHAR(50)
	)

	IF @Todate > @MoveBetsDay
	BEGIN
		IF @Bettype IN (1231, 1232, 1233, 1237, 1238)
		BEGIN
			INSERT INTO @AgWinlossHR 
			SELECT
				r.sporttype,
				b.username,
				b.custid,
				b.bettype,
				b.transid,
				b.oddsid AS race,
				o.RacerNum matchcode,
				o.RacerID homeid,
				0 awayid,
				b.hdp1,
				b.hdp2,
				b.modds,
				b.odds,
				b.status,
				b.stake,
				(b.winlost-actual_stake),
				b.awinlost,
				b.mwinlost,
				b.swinlost,
				b.playercomm,
				(b.comm - b.playercomm) AS comm,
				(b.acomm - b.comm) AS acomm,
				(b.scomm - b.acomm) AS scomm,
				b.transdate,
				'',
				b.apositiontaking,
				b.mpositiontaking,
				b.spositiontaking, 
				b.discount,
				b.adiscount,
				b.sdiscount,
				0,
				b.livehomescore,
				b.liveawayscore,
				r.leagueID,
				b.matchid,
				b.ip,
				NULL,
				CONVERT(BIT,0) AS IsNeutral,
				CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus,
				b.refno,
				r.EventTime AS showtime
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN dbo.VSOutright AS o WITH (NOLOCK) ON b.oddsid = o.orid
				INNER JOIN dbo.VSRaceInfo AS r WITH (NOLOCK) ON r.EventID = o.EventID
			WHERE b.Recommend = @CustID
				AND b.Winlostdate >= @FromDate
				AND b.Winlostdate <= @ToDate
				AND b.matchid = @Race
				AND b.Bettype = @Bettype
				AND b.Ruben = 1
		END
		ELSE
		BEGIN
			INSERT INTO @AgWinlossHR 
			SELECT
				l.sporttype,
				b.username,
				b.custid,
				b.bettype,
				b.transid,
				m.groupmatch AS race,
				m.matchcode,
				m.teamID,
				0,
				b.hdp1,
				b.hdp2,
				modds,
				b.odds,
				b.status,
				b.stake,
				(b.winlost-actual_stake),
				b.awinlost,
				b.mwinlost,
				b.swinlost,
				b.playercomm,
				(b.comm - b.playercomm) AS comm,
				(b.acomm - b.comm) AS acomm,
				(b.scomm - b.acomm) AS scomm,
				b.transdate,
				'',
				b.apositiontaking,
				b.mpositiontaking,
				b.spositiontaking,
				b.discount,
				b.adiscount,
				b.sdiscount, 
				0,
				b.livehomescore,
				b.liveawayscore,  
				l.leagueID,  
				b.matchid,   
				b.ip,
  				NULL,  
				CONVERT(BIT,0) AS IsNeutral,
				CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus,
				b.refno,
				'' AS showtime
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN dbo.outright AS m WITH (NOLOCK) ON b.matchid = m.orid
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueID = l.leagueID
			WHERE  
				b.Recommend = @CustID AND  
				b.Winlostdate >= @FromDate AND  
				b.Winlostdate <= @ToDate AND  
				l.leagueid = @LeagueId And  
				m.groupmatch = @Race AND  
				b.Bettype= @Bettype AND  
				b.Ruben = 1 
		END
	END

	IF @Fromdate <= @MoveBetsDay  
	BEGIN
		IF @Bettype IN (1231,1232,1233,1237,1238)
			INSERT INTO @AgWinlossHR 
			SELECT  
				r.sporttype,  
				b.username,  
				b.custid,
				b.bettype,
				b.transid,  
				b.oddsid AS race,  
				o.RacerNum matchcode,  
				o.RacerID homeid,  
				0 awayid,  
				b.hdp1,  
				b.hdp2,  
				modds,
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
				'',  
				b.apositiontaking,
				b.mpositiontaking,
				b.spositiontaking, 
				b.discount,
				b.adiscount,
				b.sdiscount, 
				0,
				b.livehomescore,
				b.liveawayscore,  
				r.leagueID,  
				b.matchid,   
				b.ip,
				NULL,  
				CONVERT(BIT,0) AS IsNeutral,
				CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus,
				b.refno,
				r.EventTime AS showtime
			FROM  
				dbo.bettrans14 b WITH (NOLOCK)   
				INNER JOIN dbo.VSOutright14 o WITH (NOLOCK) ON b.oddsid = o.orid   
				INNER JOIN dbo.VSRaceInfo r WITH (NOLOCK) ON r.EventID = o.EventID
			WHERE  
				b.Recommend = @CustID AND  
				b.Winlostdate >= @FromDate AND  
				b.Winlostdate <= @ToDate AND  
				b.matchid = @Race AND  
				b.Bettype= @Bettype AND  
				b.Ruben = 1  
		ELSE
			INSERT INTO @AgWinlossHR 
			SELECT  
				l.sporttype,  
				b.username,  
				b.custid,
				b.bettype,
				b.transid,  
				m.groupmatch AS race,  
				m.matchcode,  
				m.teamID,  
				0,  
				b.hdp1,  
				b.hdp2,  
				modds,
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
				'',  
				b.apositiontaking,
				b.mpositiontaking,
				b.spositiontaking, 
				b.discount,
				b.adiscount,
				b.sdiscount,
				0,
				b.livehomescore,
				b.liveawayscore,    
				l.leagueID,  
				b.matchid,   
				b.ip,
				NULL,  
				CONVERT(BIT,0) AS IsNeutral,
				CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus,
				b.refno,
				'' AS showtime
			FROM  
				dbo.bettrans14 b WITH (NOLOCK)   
				INNER JOIN dbo.outright14 m WITH (NOLOCK) ON b.matchid = m.orid   
				INNER JOIN dbo.League l WITH (NOLOCK) ON m.leagueID = l.leagueID  
			WHERE  
				b.Recommend = @CustID AND  
				b.Winlostdate >= @FromDate AND  
				b.Winlostdate <= @ToDate AND  
				l.leagueid = @LeagueId And  
				m.groupmatch = @Race AND  
				b.Bettype = @Bettype AND  
				b.Ruben = 1   
	END  
  
	SELECT * FROM @AgWinlossHR
	ORDER BY Status,
		Transid

	-- Get sub tickets
	DECLARE @Bettransm TABLE (
		RefNo			BIGINT,
		FinalOdds		MONEY,
		Odds			MONEY,
		Status			NVARCHAR(10),
		APositionTaking	SMALLMONEY,
		MPositionTaking	SMALLMONEY,
		SPositionTaking	SMALLMONEY,
		BetType			SMALLINT
	)

	-- Horse Racing (bettype 33, 43)
	IF EXISTS (	SELECT 1
				FROM @AgWinlossHR AS b
					INNER JOIN @SportBettype AS sbt ON b.BetType = sbt.Bettype
				WHERE sbt.ProductID = 2)
	BEGIN
		IF @Todate > @MoveBetsDay
		BEGIN
			INSERT INTO @Bettransm
			SELECT
				bm.refno,
				bm.finalodds,
				bm.odds,
				bm.status,
				bm.apositiontaking,
				bm.mpositiontaking,
				bm.spositiontaking,
				bm.bettype
			FROM dbo.bettransm AS bm WITH (NOLOCK)
				INNER JOIN @AgWinlossHR AS b ON bm.refno = b.transid AND bm.custid = b.CustId
				INNER JOIN @SportBettype AS sbtm ON bm.bettype = sbtm.Bettype
			WHERE sbtm.ProductID = 2
		END
		
		IF @Fromdate <= @MoveBetsDay
		BEGIN
			INSERT INTO @Bettransm
			SELECT 
				bm.refno, 
				bm.finalodds,
				bm.odds, 
				bm.status, 
				bm.apositiontaking, 
				bm.mpositiontaking, 
				bm.spositiontaking,
				bm.bettype  
			FROM dbo.bettransm14 AS bm WITH (NOLOCK)
				INNER JOIN @AgWinlossHR AS b ON bm.refno = b.transid AND bm.custid = b.CustId
				INNER JOIN @SportBettype AS sbtm ON bm.bettype = sbtm.Bettype
			WHERE sbtm.ProductID = 2
		END
	END

	-- Virtual Sports (bettype 1233)
	IF EXISTS (	SELECT 1
				FROM @AgWinlossHR AS b
					INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
				WHERE sbt.ProductId = 5 AND sbt.EventType = 3)
	BEGIN
		IF @Todate > @MoveBetsDay 
		BEGIN
			INSERT INTO @Bettransm
			SELECT 
				bm.refno, 
				bm.finalodds,
				bm.odds, 
				bm.status, 
				bm.apositiontaking, 
				bm.mpositiontaking, 
				bm.spositiontaking,
				bm.bettype  
			FROM dbo.bettransm AS bm WITH (NOLOCK)
				INNER JOIN @AgWinlossHR AS b ON bm.refno = b.refno AND bm.custid = b.CustId
				INNER JOIN @SportBettype AS sbtm ON bm.bettype = sbtm.Bettype
			WHERE sbtm.ProductID = 5 AND sbtm.EventType = 3
		END
		
		IF @Fromdate <= @MoveBetsDay
		BEGIN
			INSERT INTO @Bettransm
			SELECT 
				bm.refno, 
				bm.finalodds,
				bm.odds, 
				bm.status, 
				bm.apositiontaking, 
				bm.mpositiontaking, 
				bm.spositiontaking,
				bm.bettype  
			FROM dbo.bettransm14 bm WITH (NOLOCK)
				INNER JOIN @AgWinlossHR b ON bm.refno = b.refno AND bm.custid = b.CustId
				INNER JOIN @SportBettype AS sbtm ON bm.bettype = sbtm.Bettype
			WHERE sbtm.ProductID = 5 AND sbtm.EventType = 3
		END	
	END

	SELECT * FROM @Bettransm 
	ORDER BY RefNo,Bettype
END


	
GO
GRANT EXECUTE ON [dbo].[Age_BetList_SelWinlossHR_Ag] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_BetList_SelWinlossHR_Ag] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_BetList_SelWinlossHR_Ag] TO [vnteam]