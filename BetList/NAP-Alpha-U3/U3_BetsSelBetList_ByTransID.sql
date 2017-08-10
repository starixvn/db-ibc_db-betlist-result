USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[U3_BetsSelBetList_ByTransID]    Script Date: 5/5/2017 5:23:01 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[U3_BetsSelBetList_ByTransID]
	@CustId		INT,
	@TransId	BIGINT
AS

/*
	Created: Dom@20150105
	DB: DBAGE.bodb02
	Task: Customer betlist by transid
	Revisions:
		- 20170725@Kos: Fix CheckBet issue [#Redmine: 80453]
					- Remove Bingo and P2P in bettrans and bettrans14 range [#Redmine: 53988]
					- Change odds, modds data type from SMALLMONEY to MONEY [Redmine: #48660]
		- 20170809@Kos: Support Lucky 3 [#Redmine: 75277]
*/

BEGIN
	SET NOCOUNT ON;

	DECLARE @Data TABLE (
		BetType				INT,
		TransId				BIGINT,
		BetId				BIGINT,
		RefNo				NVARCHAR(50),
		MatchCode			NVARCHAR(50),
		Race				NVARCHAR(20),
		EventDate			SMALLDATETIME,
		VirtualRate			FLOAT,
		IsShowOTExRate		BIT,
		SDiscount			SMALLMONEY,
		ADiscount			SMALLMONEY,
		Discount			SMALLMONEY,
		HomeId				INT,
		AwayId				INT,
		SettleTime			DATETIME,
		Hdp1				SMALLMONEY,
		Hdp2				SMALLMONEY,
		Odds				MONEY,
		FinalOdds			MONEY,
		FinalOdds2			MONEY,
		OddsType			TINYINT,
		Status				NVARCHAR(50),
		ComStatus			NVARCHAR(50),
		Stake				MONEY,
		Actual_Stake		MONEY,
		TransDate			DATETIME,
		BetTeam				NVARCHAR(10),
		SPositionTaking		SMALLMONEY,
		MPositionTaking		SMALLMONEY,
		APositionTaking		SMALLMONEY,
		SPositionTaking2	SMALLMONEY,
		MPositionTaking2	SMALLMONEY,
		APositionTaking2	SMALLMONEY,
		LiveIndicator		BIT,
		MOdds				MONEY,
		CustId				INT,
		LiveHomeScore		INT,
		LiveAwayScore		INT,
		FinalHomeScore		INT,
		FinalAwayScore		INT,
		LeagueId			INT,
		SportType			SMALLINT,
		Ip					NVARCHAR(15),
		BetFrom				NVARCHAR(1),
		MatchId				INT,
		IsNeutral			BIT,
		AllowDelete			BIT,
		WinLost				MONEY,
		Commission			MONEY,
		SComm				MONEY,
		AComm				MONEY,
		Comm				MONEY,
		AWinLost			MONEY,
		MWinLost			MONEY,
		SWinLost			MONEY,
		ShowTime			NVARCHAR(50),
		WinLostDate			SMALLDATETIME,
		BetCheck			NVARCHAR(50),
		TransDesc			NVARCHAR(1000),
		OddsSpread			MONEY,
		OriginalBetType		INT,
		BetdaqId			BIGINT,
		ExtraInfo			VARCHAR(1000)
	)

	DECLARE @DetailData TABLE (
		RefNo			NVARCHAR(50),
		Odds			MONEY,
		Stake			MONEY,
		Status			NVARCHAR(50),
		APositionTaking	SMALLMONEY,
		MPositionTaking	SMALLMONEY,
		SPositionTaking	SMALLMONEY,
		BetType			SMALLINT,
		BetTeam			NVARCHAR(50)
	)

	DECLARE @refno BIGINT,
		@WinLostDate SMALLDATETIME,
		@MoveBetsDay SMALLDATETIME,
		@BalanceUpDay SMALLDATETIME,
		@BetType INT

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
	WHERE ProductID IN (3, 4, 7, 26)

	-- FROM bettrans
	SELECT TOP(1)
		@WinLostDate = b.winlostdate,
		@BetType = b.bettype
	FROM dbo.bettrans AS b WITH (NOLOCK)
		INNER JOIN @SportBettype AS sp ON b.bettype = sp.bettype
	WHERE b.custid = @CustId AND b.transid = @TransId

	-- FROM bettrans14
	IF @WinLostDate IS NULL
	BEGIN
		SELECT TOP(1)
			@WinLostDate = b.winlostdate,
			@BetType = b.bettype
		FROM dbo.bettrans14 AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS sp ON b.bettype = sp.bettype
		WHERE b.custid = @CustId AND b.transid = @TransId
	END

	-- FROM bettrans_bk
	IF @WinLostDate IS NULL
	BEGIN
		SELECT TOP(1)
			@WinLostDate = b.winlostdate,
			@BetType = b.bettype
		FROM DBARC.bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS sp ON b.bettype = sp.bettype
		WHERE b.custid = @CustId
			AND (b.transid = @TransId
				OR (b.refno = @TransId AND sp.productid = 7))
	END

	IF @WinLostDate IS NOT NULL
	BEGIN
		-- Bettrans
		IF @WinLostDate > @MoveBetsDay
		BEGIN
			-- Number Game, Live Casino, Lucky 3
			IF EXISTS (SELECT TOP(1) 1 FROM @SportBettype WHERE EventType = 1 AND Bettype = @BetType)
			BEGIN
				INSERT INTO @Data
				SELECT
					b.bettype,
					b.transid,
					ISNULL(b.betid, 0) AS BetID,
					b.refno,
					m.matchcode,
					'' AS race,
					m.eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					CASE
						WHEN s.ProductID = 26 THEN 0
						ELSE b.sdiscount
					END AS SDiscount,
					CASE
						WHEN s.ProductID = 26 THEN 0
						ELSE b.adiscount
					END AS ADiscount,
					CASE
						WHEN s.ProductID = 26 THEN 0
						ELSE b.discount
					END AS Discount,
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
					m.finalhomescore,
					m.finalawayscore,
					m.leagueid,
					m.sporttype,
					b.ip,
					b.betfrom,
					b.matchid,
					ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
					0 AS allowdelete,
					(b.winlost - b.actual_stake) AS winlost,
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
					CASE
						WHEN s.ProductID = 26 THEN ISNULL(b.transdesc, '')
						ELSE ''
					END AS TransDesc,
					0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					'' AS ExtraInfo
				FROM
					dbo.bettrans AS b WITH (NOLOCK)
					INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
					INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
				WHERE
					b.custid = @CustId
					AND b.transid = @TransId
					AND s.EventType = 1
			END
		END

		-- Bettrans14
		ELSE IF @WinLostDate <= @MoveBetsDay AND @WinLostDate >= @BalanceUpDay
		BEGIN
			-- Number Game, Live Casino, Lucky 3
			IF EXISTS (SELECT TOP(1) 1 FROM @SportBettype WHERE EventType = 1 AND Bettype = @BetType)
			BEGIN
				INSERT INTO @Data
				SELECT
					b.bettype,
					b.transid,
					ISNULL(b.betid, 0) AS BetID,
					b.refno,
					m.matchcode,
					'' AS race,
					m.eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					CASE
						WHEN s.ProductID = 26 THEN 0
						ELSE b.sdiscount
					END AS SDiscount,
					CASE
						WHEN s.ProductID = 26 THEN 0
						ELSE b.adiscount
					END AS ADiscount,
					CASE
						WHEN s.ProductID = 26 THEN 0
						ELSE b.discount
					END AS Discount,
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
					m.finalhomescore,
					m.finalawayscore,
					m.leagueid,
					m.sporttype,
					b.ip,
					b.betfrom,
					b.matchid,
					ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
					0 AS allowdelete,
					(b.winlost - b.actual_stake) AS winlost,
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
					CASE
						WHEN s.ProductID = 26 THEN ISNULL(b.transdesc, '')
						ELSE ''
					END AS TransDesc,
					0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					'' AS ExtraInfo
				FROM
					dbo.bettrans14 AS b WITH (NOLOCK)
					INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
					INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
				WHERE
					b.custid = @CustId
					AND b.transid = @TransId
					AND s.EventType = 1
			END
		END

		--Bettransbk
		ELSE IF @WinLostDate < @BalanceUpDay
		BEGIN
			-- Number Game, Live Casino, Lucky 3
			IF EXISTS (SELECT TOP(1) 1 FROM @SportBettype WHERE EventType = 1 AND Bettype = @BetType)
			BEGIN
				INSERT INTO @Data
				SELECT
					b.bettype,
					b.transid,
					ISNULL(b.betid, 0) AS BetID,
					b.refno,
					m.matchcode,
					'' AS race,
					m.eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					CASE
						WHEN s.ProductID = 26 THEN 0
						ELSE b.sdiscount
					END AS SDiscount,
					CASE
						WHEN s.ProductID = 26 THEN 0
						ELSE b.adiscount
					END AS ADiscount,
					CASE
						WHEN s.ProductID = 26 THEN 0
						ELSE b.discount
					END AS Discount,
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
					m.finalhomescore,
					m.finalawayscore,
					m.leagueid,
					m.sporttype,
					b.ip,
					b.betfrom,
					b.matchid,
					ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
					0 AS allowdelete,
					(b.winlost - b.actual_stake) AS winlost,
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
					CASE
						WHEN s.ProductID = 26 THEN ISNULL(b.transdesc, '')
						ELSE ''
					END AS TransDesc,
					0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					'' AS ExtraInfo
				FROM
					DBARC.bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK)
					INNER JOIN DBARC.bodb_Archive.dbo.match_bk AS m WITH (NOLOCK) ON b.matchid = m.matchid
					INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
				WHERE
					b.custid = @Custid
					AND b.transid = @TransID
					AND s.EventType = 1
			END

			-- Bingo
			IF @BetType = 73
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
					b.sdiscount,
					b.adiscount,
					b.discount,
					0 AS homeid,
					0 AS awayid,
					'' settleTime,
					b.hdp1,
					b.hdp2,
					b.odds,
					0 finalodds,
					0 finalodds2,
					0 AS OddsType,
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
					(b.winlost - b.actual_stake) AS winlost,
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
				FROM DBARC.bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
				WHERE
					b.custid = @Custid
					AND b.refno = @TransID
					AND s.ProductID = 7
			END
		END
	END

	SELECT b.*,
		ex.currency
	FROM @Data AS b
		LEFT JOIN dbo.custInfo AS ci WITH (NOLOCK) ON b.CustId = ci.custid
		LEFT JOIN dbo.Exchange AS ex WITH (NOLOCK) ON ci.currency = ex.exchangeid
	ORDER BY b.TransId

	IF @BetType BETWEEN 1101 AND 1199
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
		FROM dbo.bettransg AS bg WITH (NOLOCK)
			INNER JOIN @Data AS b ON bg.refno = b.refno
		WHERE b.BetType BETWEEN 1101 AND 1199

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
		FROM dbo.bettransg14 AS bg WITH (NOLOCK)
			INNER JOIN @Data AS b ON bg.refno = b.refno
		WHERE b.BetType BETWEEN 1101 AND 1199

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
		FROM DBARC.bodb_Archive.dbo.bettransg AS bg WITH (NOLOCK)
			INNER JOIN @Data AS b ON bg.refno = b.refno
		WHERE b.Bettype BETWEEN 1101 AND 1199

		SELECT DISTINCT * FROM @DetailData
	END
END

GO
GRANT	EXECUTE	ON	U3_BetsSelBetList_ByTransID	TO	bodbAdminNet
GRANT	VIEW DEFINITION	ON	U3_BetsSelBetList_ByTransID	TO	vnteam
GRANT	EXECUTE	ON	U3_BetsSelBetList_ByTransID	TO	bodbExtAccNet
GO
