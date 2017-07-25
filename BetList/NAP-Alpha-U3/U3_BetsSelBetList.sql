USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[U3_BetsSelBetList]    Script Date: 5/5/2017 5:24:58 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[U3_BetsSelBetList]  
	@FromDate		DATETIME,  
	@ToDate			DATETIME,  
	@MoveBetsDay	DATETIME, 
	@CustID			INT,
	@Bettype		INT = 0
AS

/*
	Created by: [Dom]
	Date: 2015-01-06
	Task: Bet List 
	DB: DBAGE/bodb02 
	Original:  Acc_BetsSelBetList

	Revisions:
		- 20170725@Kos: Fix CheckBet issue [#Redmine: 80453]
					- Remove Bingo and P2P in bettrans and bettrans14 range [#Redmine: 53988]
					- Change odds, modds data type from SMALLMONEY to MONEY [Redmine: #48660]
*/

BEGIN
	SET NOCOUNT ON

	-- Get Sport Bettype Matrix
	DECLARE @SportBettype TABLE(ProductID TINYINT, Bettype SMALLINT, EventType TINYINT)

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype
	SELECT ProductID, BetType, EventType
	FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest)
	WHERE ProductID IN (3, 4)

	DECLARE @Data TABLE (
		bettype				INT,
		transid				BIGINT, 
		betid				BIGINT,
		refno				NVARCHAR(50), 
		matchcode			NVARCHAR(50),
		race				NVARCHAR(20),
		eventdate			SMALLDATETIME,
		virtualrate			FLOAT,
		isShowOTExRate		BIT,
		sdiscount			SMALLMONEY,
		adiscount			SMALLMONEY,
		discount			SMALLMONEY,
		homeid				INT, 
		awayid				INT, 
		settleTime			DATETIME,
		hdp1				SMALLMONEY, 
		hdp2				SMALLMONEY, 
		odds				MONEY,
		finalodds			MONEY,
		finalodds2			MONEY,
		OddsType			TINYINT,
		status				NVARCHAR(50),
		comstatus			NVARCHAR(50), 
		stake				MONEY,
		actual_stake		MONEY,
		transdate			DATETIME,
		betteam				NVARCHAR(10),
		spositiontaking		SMALLMONEY,
		mpositiontaking		SMALLMONEY,
		apositiontaking		SMALLMONEY,
		spositiontaking2	SMALLMONEY,
		mpositiontaking2	SMALLMONEY,
		apositiontaking2	SMALLMONEY,
		liveindicator		BIT,
		modds				MONEY,
		custid				INT,
		livehomescore		INT, 
		liveawayscore		INT, 
		finalhomescore		INT, 
		finalawayscore		INT, 
		leagueid			INT, 
		sporttype			SMALLINT, 
		ip					NVARCHAR(15), 
		betfrom				NVARCHAR (1),
		matchid				INT,
		isNeutral			BIT,
		allowdelete			BIT,
		winlost				MONEY,
		commission			MONEY,
		scomm				MONEY,	
		acomm				MONEY,
		comm				MONEY,
		awinlost			MONEY,
		mwinlost			MONEY,
		swinlost			MONEY,
		showtime			NVARCHAR(50),
		winlostdate			SMALLDATETIME,
		BetCheck			NVARCHAR(50),
		TransDesc			NVARCHAR(1000),
		OddsSpread			MONEY,
		OriginalBetType		INT,
		BetdaqId			BIGINT,
		ExtraInfo			VARCHAR(1000)
	)

	DECLARE @DetailData TABLE (
		refno			NVARCHAR(50), 
		odds			MONEY, 
		stake			MONEY,
		status			NVARCHAR(50),
		apositiontaking SMALLMONEY, 
		mpositiontaking SMALLMONEY, 
		spositiontaking SMALLMONEY,
		bettype			SMALLINT,
		betteam			NVARCHAR(50)
	)

	IF @Bettype = 0
	BEGIN
		IF @Todate > @MoveBetsDay
		BEGIN
			INSERT INTO @Data
			SELECT 
				b.bettype,
				b.transid,
				ISNULL(b.betid,0),
				b.refno,
				m.matchcode,
				'' AS race,
				m.eventdate AS eventdate,
				0,
				0,
				b.sdiscount,
				b.adiscount,
				b.discount,	
				m.homeid,
				m.awayid,
				ISNULL(b.checktime,'') settleTime,
				b.hdp1,
				b.hdp2,
				b.odds,   
				0 finalodds,
				0 finalodds2,
				b.OddsType,  
				CASE
					WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
					ELSE b.status 
				END AS status,
				CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus, 
				stake,
				actual_stake,
				b.transdate,
				b.betteam, 
				b.spositiontaking,   
				b.mpositiontaking,   
				b.apositiontaking,
				0 spositiontaking2,
				0 mpositiontaking2,
				0 apositiontaking2,   
				b.liveindicator,   
				b.modds,   
				b.custid,
				b.livehomescore, 
				b.liveawayscore, 
				m.finalhomescore, 
				m.finalawayscore, 
				m.leagueid,
				m.sporttype,
				b.ip,
				b.betfrom,
				b.matchid,
				ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
				0 AS allowdelete,
				(b.winlost-b.actual_stake)  winlost,
				b.playercomm AS commission,
				(b.scomm - b.acomm),
				(b.acomm - b.comm),
				(b.comm - b.playercomm),
				b.awinlost,
				b.mwinlost,
				b.swinlost,
				m.showtime,
				b.winlostdate,
				'' AS BetCheck,
				'' AS transdesc,
				0 AS OddsSpread,
				0 AS OriginalBetType,
				-1 AS BetdaqId,
				'' AS ExtraInfo
			FROM 
				dbo.bettrans AS b WITH (NOLOCK) 
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype s ON s.Bettype = b.bettype
			WHERE b.winlostdate>= @FromDate AND    
				b.winlostdate<= @ToDate AND   
				b.custid = @Custid AND
				s.ProductID IN (3,4)
		END

		IF @Fromdate <= @MoveBetsDay
		BEGIN
			INSERT INTO @Data
			SELECT 
				b.bettype,
				b.transid,
				ISNULL(b.betid,0),
				b.refno,
				m.matchcode,
				'' AS race,
				m.eventdate AS eventdate,
				0,
				0,
				b.sdiscount,
				b.adiscount,
				b.discount,	
				m.homeid,
				m.awayid,
				ISNULL(b.checktime,'') settleTime,
				b.hdp1,
				b.hdp2,
				b.odds,   
				0 finalodds,
				0 finalodds2,
				b.OddsType,  
				CASE
					WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
					ELSE b.status 
				END AS status,
				CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus, 
				stake,
				actual_stake,
				b.transdate,
				b.betteam, 
				b.spositiontaking,   
				b.mpositiontaking,   
				b.apositiontaking,
				0 spositiontaking2,
				0 mpositiontaking2,
				0 apositiontaking2,   
				b.liveindicator,   
				b.modds,   
				b.custid,
				b.livehomescore, 
				b.liveawayscore, 
				m.finalhomescore, 
				m.finalawayscore, 
				m.leagueid,
				m.sporttype,
				b.ip,
				b.betfrom,
				b.matchid,
				ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
				0 AS allowdelete,
				(b.winlost-b.actual_stake)  winlost,
				b.playercomm AS commission,
				(b.scomm - b.acomm),
				(b.acomm - b.comm),
				(b.comm - b.playercomm),
				b.awinlost,
				b.mwinlost,
				b.swinlost,
				m.showtime,
				b.winlostdate,
				'' AS BetCheck,
				'' AS transdesc,
				0 AS OddsSpread,
				0 AS OriginalBetType,
				-1 AS BetdaqId,
				'' AS ExtraInfo
			FROM 
				dbo.bettrans14 AS b WITH (NOLOCK) 
				INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype s ON s.Bettype = b.bettype
			WHERE b.winlostdate>= @FromDate AND    
				b.winlostdate<= @ToDate AND   
				b.custid = @Custid AND
				s.ProductID IN (3,4)
		END
	END
	ELSE --@Bettype<>0
	BEGIN
		IF @bettype IN (SELECT Bettype FROM @SportBettype WHERE ProductID IN(3,4))
		BEGIN
			IF @Todate > @MoveBetsDay
			BEGIN
				INSERT INTO @Data
				SELECT 
					b.bettype,
					b.transid,
					ISNULL(b.betid,0),
					b.refno,
					m.matchcode,
					'' AS race,
					m.eventdate AS eventdate,
					0,
					0,
					b.sdiscount,
					b.adiscount,
					b.discount,	
					m.homeid,
					m.awayid,
					ISNULL(b.checktime,'') settleTime,
					b.hdp1,
					b.hdp2,
					b.odds,   
					0 finalodds,
					0 finalodds2,
					b.OddsType,  
					CASE
						WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
						ELSE b.status 
					END AS status,
					CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus, 
					stake,
					actual_stake,
					b.transdate,
					b.betteam, 
					b.spositiontaking,   
					b.mpositiontaking,   
					b.apositiontaking,
					0 spositiontaking2,
					0 mpositiontaking2,
					0 apositiontaking2,   
					b.liveindicator,   
					b.modds,   
					b.custid,
					b.livehomescore, 
					b.liveawayscore, 
					m.finalhomescore, 
					m.finalawayscore, 
					m.leagueid,
					m.sporttype,
					b.ip,
					b.betfrom,
					b.matchid,
					ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
					0 AS allowdelete,
					(b.winlost-b.actual_stake)  winlost,
					b.playercomm AS commission,
					(b.scomm - b.acomm),
					(b.acomm - b.comm),
					(b.comm - b.playercomm),
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					m.showtime,
					b.winlostdate,
					'' AS BetCheck,
					'' AS transdesc,
					0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					'' AS ExtraInfo
				FROM 
					dbo.bettrans AS b WITH (NOLOCK) 
					INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
					INNER JOIN @SportBettype s ON s.Bettype = b.bettype
				WHERE b.bettype = @Bettype AND
					b.winlostdate>= @FromDate AND    
					b.winlostdate<= @ToDate AND   
					b.custid = @Custid AND
					s.PRODUCTID IN (3,4)
			END
			IF @Fromdate <= @MoveBetsDay
			BEGIN
				INSERT INTO @Data
				SELECT 
					b.bettype,
					b.transid,
					ISNULL(b.betid,0),
					b.refno,
					m.matchcode,
					'' AS race,
					m.eventdate AS eventdate,
					0,
					0,
					b.sdiscount,
					b.adiscount,
					b.discount,	
					m.homeid,
					m.awayid,
					ISNULL(b.checktime,'') settleTime,
					b.hdp1,
					b.hdp2,
					b.odds,   
					0 finalodds,
					0 finalodds2,
					b.OddsType,  
					CASE
						WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
						ELSE b.status 
					END AS status,
					CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus, 
					stake,
					actual_stake,
					b.transdate,
					b.betteam, 
					b.spositiontaking,   
					b.mpositiontaking,   
					b.apositiontaking,
					0 spositiontaking2,
					0 mpositiontaking2,
					0 apositiontaking2,   
					b.liveindicator,   
					b.modds,   
					b.custid,
					b.livehomescore, 
					b.liveawayscore, 
					m.finalhomescore, 
					m.finalawayscore, 
					m.leagueid,
					m.sporttype,
					b.ip,
					b.betfrom,
					b.matchid,
					ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
					0 AS allowdelete,
					(b.winlost-b.actual_stake)  winlost,
					b.playercomm AS commission,
					(b.scomm - b.acomm),
					(b.acomm - b.comm),
					(b.comm - b.playercomm),
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					m.showtime,
					b.winlostdate,
					'' AS BetCheck,
					'' AS transdesc,
					0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					'' AS ExtraInfo
				FROM 
					dbo.bettrans14 AS b WITH (NOLOCK) 
					INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
					INNER JOIN @SportBettype s ON s.Bettype = b.bettype
				WHERE b.bettype = @Bettype AND
					b.winlostdate>= @FromDate AND    
					b.winlostdate<= @ToDate AND   
					b.custid = @Custid AND
					s.PRODUCTID IN (3,4)
			END
		END
	END

	SELECT * 
	FROM @Data
	ORDER BY transid  

	INSERT INTO @DetailData
	SELECT 
		bg.refno, 
		bg.odds, 
		bg.stake,
		bg.status,
		bg.apositiontaking, 
		bg.mpositiontaking, 
		bg.spositiontaking,
		bg.bettype,
		bg.betteam  
	FROM dbo.bettransg bg with (NOLOCK)
		INNER JOIN @Data B ON bg.refno = B.refno
	WHERE B.Bettype BETWEEN 1101 AND 1199

	INSERT INTO @DetailData
	SELECT 
		bg.refno, 
		bg.odds, 
		bg.stake,
		bg.status,
		bg.apositiontaking, 
		bg.mpositiontaking, 
		bg.spositiontaking,
		bg.bettype,
		bg.betteam  
	FROM dbo.bettransg14 bg with (NOLOCK)
		INNER JOIN @Data B ON bg.refno = B.refno
	WHERE B.Bettype BETWEEN 1101 AND 1199

	SELECT DISTINCT * FROM @DetailData
END


GO
GRANT	EXECUTE	ON	U3_BetsSelBetList	TO	bodbAdminNet
GRANT	VIEW DEFINITION	ON	U3_BetsSelBetList	TO	vnteam
GRANT	EXECUTE	ON	U3_BetsSelBetList	TO	bodbExtAccNet
GO
