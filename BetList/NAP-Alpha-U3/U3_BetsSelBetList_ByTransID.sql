USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[U3_BetsSelBetList_ByTransID]    Script Date: 5/5/2017 5:23:01 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.U3_BetsSelBetList_ByTransID    Script Date: 1/15/2015 10:22:03 PM ******/
/****** Object:  Stored Procedure dbo.U3_BetsSelBetList_ByTransID    Script Date: 1/14/2015 2:40:23 PM ******/
ALTER PROCEDURE [dbo].[U3_BetsSelBetList_ByTransID]
	@CustID		INT,
	@TransID	BIGINT
AS


/*
	Created: Dom
	Date: 05/01/2015
	DB: DBAGE/BODB02
	Task: Customer betlist by transid
	Revisions:
		- 20170725@Kos: Fix CheckBet issue [#Redmine: 80453]
					- Remove Bingo and P2P in bettrans and bettrans14 range [#Redmine: 53988]
					- Change odds, modds data type from SMALLMONEY to MONEY [Redmine: #48660]
*/

BEGIN
	SET NOCOUNT ON;
	
	DECLARE @refno BIGINT

	Declare @Data TABLE (
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
		betFROM				NVARCHAR (1),  
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
		apositiontaking	SMALLMONEY,   
		mpositiontaking	SMALLMONEY,   
		spositiontaking	SMALLMONEY,  
		bettype			SMALLINT,  
		betteam			NVARCHAR(50)  
	)

	DECLARE @WinlostDate SMALLDATETIME,
		@MoveBetsDay SMALLDATETIME,
		@BalanceUpDay SMALLDATETIME,
		@bettype INT

	DECLARE @tmp TABLE (BalanceUpDay SMALLDATETIME, MoveBetsDay SMALLDATETIME) 

	INSERT INTO @tmp(BalanceUpDay, MoveBetsDay)
	EXEC Age_SelBalanceUpDay

	SELECT @MoveBetsDay = MoveBetsDay,
		@BalanceUpDay = BalanceUpDay
	FROM @tmp

	-- Get Sport Bettype Matrix
	DECLARE @SportBettype TABLE(ProductID TINYINT, Bettype SMALLINT, EventType INT)

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype
	SELECT ProductID, BetType, EventType
	FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest)
	WHERE ProductID IN (3, 4, 7)

	IF EXISTS ( SELECT top 1 1 FROM dbo.bettrans WITH (NOLOCK)
				WHERE transid = @TransID
					OR (refno = @transid AND bettype = 73 AND matchid IN (0,73))
					AND custid = @Custid )
		SELECT @WinlostDate = winlostdate,
			@bettype = bettype
		FROM bettrans WITH (NOLOCK)
		WHERE transid = @TransID OR (refno = @transid AND bettype = 73 AND matchid IN (0,73))
			AND custid = @Custid
	ELSE IF EXISTS ( SELECT top 1 1 FROM dbo.bettrans14 WITH (NOLOCK)   
					WHERE transid = @TransID OR (refno = @transid AND bettype = 73 AND matchid IN (0,73))
						AND custid = @Custid )
		SELECT @WinlostDate = winlostdate,
			@bettype = bettype 
		FROM dbo.bettrans14 WITH (NOLOCK)
		WHERE transid = @TransID OR (refno = @transid AND bettype = 73 AND matchid IN (0,73))
			AND custid = @Custid
	ELSE IF EXISTS ( SELECT top 1 1 FROM DBARC.bodb_archive.dbo.bettrans_bk WITH (NOLOCK)   
					WHERE transid = @TransID OR (refno = @transid AND bettype = 73 AND matchid IN (0,73))
						AND custid = @Custid )
		SELECT @WinlostDate = winlostdate,
			@bettype = bettype 
		FROM DBARC.bodb_archive.dbo.bettrans_bk WITH (NOLOCK)   
		WHERE transid = @TransID OR (refno = @transid AND bettype = 73 AND matchid IN (0,73))
			AND custid = @Custid 

	--Bettrans
	IF @WinlostDate > @MoveBetsDay
	BEGIN  
		IF EXISTS(SELECT * FROM @SportBettype WHERE ProductID IN(3,4) AND bettype = @bettype)--LS and NumberGame
		BEGIN
			INSERT INTO @Data  
			SELECT   
				b.bettype,  
				b.transid,  
				ISNULL(b.BetID,0) AS BetID,  
				b.refno,  
				m.matchcode,  
				'' AS race,  
				m.eventdate AS eventdate,  
				0 AS virtualrate,  
				0 AS isShowOTExRate,  
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
				b.actual_stake,  
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
				b.betFROM,  
				b.matchid,  
				ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
				0 AS allowdelete,  
				(b.winlost-b.actual_stake)  winlost,  
				b.playercomm AS commission,  
				(b.scomm - b.acomm) AS scomm,  
				(b.acomm - b.comm) AS acomm,  
				(b.comm - b.playercomm) AS comm,  
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
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid --phuong.nguyen, remove left join match_remark  
				INNER JOIN @SportBettype s ON s.Bettype = b.bettype
			WHERE    
				b.custid = @Custid AND
				s.ProductID IN (3,4) 
				AND b.transid = @TransID  
		END --END LS and NumberGame
	END---END Bettrans

	--Bettrans14
	ELSE IF @WinlostDate <= @MoveBetsDay AND @WinlostDate >= @BalanceUpDay
	BEGIN  
		IF EXISTS (SELECT * FROM @SportBettype WHERE ProductID IN(3,4) AND bettype = @bettype)--LS and NumberGame
		BEGIN
			INSERT INTO @Data  
			SELECT   
				b.bettype,  
				b.transid,  
				ISNULL(b.BetID,0) AS BetID,  
				b.refno,  
				m.matchcode,  
				'' AS race,  
				m.eventdate AS eventdate,  
				0 AS virtualrate,  
				0 AS isShowOTExRate,  
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
				b.actual_stake,  
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
				b.betFROM,  
				b.matchid,  
				ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
				0 AS allowdelete,  
				(b.winlost-b.actual_stake)  winlost,  
				b.playercomm AS commission,  
				(b.scomm - b.acomm) AS scomm,  
				(b.acomm - b.comm) AS acomm,  
				(b.comm - b.playercomm) AS comm,  
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
				INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid --phuong.nguyen, remove left join match_remark  
				INNER JOIN @SportBettype s ON s.Bettype = b.bettype
			WHERE    
				b.custid = @Custid AND
				s.ProductID IN (3,4) 
				AND b.transid = @TransID  
		END --END LS and NumberGame
	END---END Bettrans14

	--Bettransbk
	ELSE IF @WinlostDate < @BalanceUpDay
	BEGIN  
		IF EXISTS (SELECT * FROM @SportBettype WHERE ProductID IN(3,4) AND bettype = @bettype)--LS AND NumberGame
		BEGIN
			INSERT INTO @Data  
			SELECT   
				b.bettype,  
				b.transid,  
				ISNULL(b.BetID,0) AS BetID,  
				b.refno,  
				m.matchcode,  
				'' AS race,  
				m.eventdate AS eventdate,  
				0 AS virtualrate,  
				0 AS isShowOTExRate,  
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
				CASE WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'  
				ELSE b.status   
				END AS status,  
				CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,  
				stake,  
				b.actual_stake,  
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
				b.betFROM,  
				b.matchid,  
				ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
				0 AS allowdelete,  
				(b.winlost-b.actual_stake)  winlost,  
				b.playercomm AS commission,  
				(b.scomm - b.acomm) AS scomm,  
				(b.acomm - b.comm) AS acomm,  
				(b.comm - b.playercomm) AS comm,  
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
				DBARC.bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK)   
				INNER JOIN DBARC.bodb_archive.dbo.match_BK AS m WITH (NOLOCK) ON b.matchid = m.matchid --phuong.nguyen, remove left join match_remark  
				INNER JOIN @SportBettype s ON s.Bettype = b.bettype
			WHERE    
				b.custid = @Custid AND
				s.ProductID IN (3,4) 
				AND b.transid = @TransID  
		END --END LS and NumberGame
		
		IF @bettype = 73 --IBC Bingo  
		BEGIN
			INSERT INTO @Data  
			SELECT   
				b.bettype,     
				b.betid transid,   
				ISNULL(b.BetID,0) AS BetID,    
				b.refno,  
				CONVERT(VARCHAR(50), b.refno) AS matchcode,     
				'' AS race,  
				'' AS eventdate,   
				0 AS virtualrate,  
				0 AS isShowOTExRate,  
				sdiscount,  
				adiscount,  
				discount,    
				0 AS homeid,     
				0 AS awayid,    
				'' settleTime,   
				b.hdp1,  
				b.hdp2,  
				b.odds,     
				0 finalodds,  
				0 finalodds2,  
				'' OddsType,    
				b.status,  
				CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,     
				b.stake,     
				b.actual_stake,  
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
				0,
				0,    
				0 AS leagueid,    
				252 AS sporttype,   
				b.ip,  
				b.betFROM,  
				b.matchid,  
				CONVERT(BIT,0) AS IsNeutral,  
				0 AS allowdelete,  
				(b.winlost-b.actual_stake)  winlost,  
				b.playercomm AS commission,  
				(b.scomm - b.acomm) AS scomm,  
				(b.acomm - b.comm) AS acomm,  
				(b.comm - b.playercomm) AS comm,  
				b.awinlost,  
				b.mwinlost,  
				b.swinlost,  
				'' AS showtime,
				b.winlostdate,
				'' AS BetCheck,
				'' AS transdesc,
				0 AS OddsSpread,
				0 AS OriginalBetType,
				-1 AS BetdaqId,
				'' AS ExtraInfo
			FROM DBARC.bodb_archive.dbo.bettrans_bk b WITH (NOLOCK)     
			INNER JOIN @SportBettype s ON s.Bettype = b.bettype
			WHERE     
				b.custid = @Custid    
				AND s.ProductID = 7
				AND b.refno = @TransID
		END --Bingo

	END---END Bettransbk

	SELECT * 
	FROM @Data  
	ORDER BY transid

	IF @bettype BETWEEN 1101 AND 1199 
	BEGIN
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
		FROM dbo.bettransg bg WITH (NOLOCK)
			INNER JOIN @Data b ON bg.refno = b.refno
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
		FROM dbo.bettransg14 bg WITH (NOLOCK)
			INNER JOIN @Data b ON bg.refno = b.refno
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
		FROM DBARC.bodb_archive.dbo.bettransg bg WITH (NOLOCK)
			INNER JOIN @Data b ON bg.refno = b.refno
		WHERE B.Bettype BETWEEN 1101 AND 1199

		SELECT DISTINCT * 
		FROM @DetailData
	END
END--END SP

GO
GRANT	EXECUTE	ON	U3_BetsSelBetList_ByTransID	TO	bodbAdminNet
GRANT	VIEW DEFINITION	ON	U3_BetsSelBetList_ByTransID	TO	vnteam
GRANT	EXECUTE	ON	U3_BetsSelBetList_ByTransID	TO	bodbExtAccNet
GO
