/*<info serverAlias="DBAGE-bodb02" executers="bodbAdminNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[U3_BetsSelBetList_ByTransID]
	@CustId	INT,
	@RefNo	BIGINT
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
		- 20201224@Kos: Support Happy 5 Linked Games [Redmine: #146540]
					- Don't support Live Casino, Bingo, Lucky 3 anymore
					- Dont return data table @DetailData anymore
					- Rename input param @TransId to @RefNo
					- Don't return column Race, FinalOdds, FinalOdds2, AllowDelete, OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, VirtualRate, IsShowOTExRate,
						SPositionTaking2, MPositionTaking2, APositionTaking2
		- 20210705@Razor: Show Odds for Happy 5 Linked Games [Redmine: #154704]
*/

BEGIN
	SET NOCOUNT ON;

	DECLARE @Data TABLE (
		BetType				INT,
		TransId				BIGINT,
		BetId				BIGINT,
		RefNo				NVARCHAR(50),
		MatchCode			NVARCHAR(50),
		EventDate			SMALLDATETIME,
		SDiscount			SMALLMONEY,
		ADiscount			SMALLMONEY,
		Discount			SMALLMONEY,
		HomeId				INT,
		AwayId				INT,
		SettleTime			DATETIME,
		Hdp1				SMALLMONEY,
		Hdp2				SMALLMONEY,
		Odds				MONEY,
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
		TransDesc			NVARCHAR(1000)
	)

	DECLARE @TransId BIGINT,
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
	DECLARE @SportBettype TABLE(ProductId TINYINT, BetType SMALLINT, EventType TINYINT, RefTable TINYINT)

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype
	SELECT ProductID, BetType, EventType, RefTable
	FROM dbo.f_SportBettypeMatrix_Sel (3, 0, 0, 2, '', '', @IsTest)

	-- FROM translog
	SELECT TOP(1)
		@TransId = b.translogid,
		@WinLostDate = b.winlostdate,
		@BetType = b.gameID,
		@RefNo = b.translogid
	FROM dbo.translog AS b WITH (NOLOCK)
		INNER JOIN @SportBettype AS sp ON b.gameID = sp.bettype
	WHERE b.custid = @CustId
		AND b.translogid = @RefNo
		AND b.statusID IN (0, 1)
		AND sp.ProductId = 3
		AND sp.EventType = 0

	-- FROM bettrans
	SELECT TOP(1)
		@TransId = b.transid,
		@WinLostDate = b.winlostdate,
		@BetType = b.bettype,
		@RefNo = b.refno
	FROM dbo.bettrans AS b WITH (NOLOCK)
		INNER JOIN @SportBettype AS sp ON b.bettype = sp.bettype
	WHERE b.custid = @CustId
		AND (b.transid = @RefNo
			OR (b.refno = @RefNo
				AND sp.ProductId = 3
				AND sp.EventType = 0))

	-- FROM bettrans14
	IF @WinLostDate IS NULL
	BEGIN
		SELECT TOP(1)
			@TransId = b.transid,
			@WinLostDate = b.winlostdate,
			@BetType = b.bettype,
			@RefNo = b.refno
		FROM dbo.bettrans14 AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS sp ON b.bettype = sp.bettype
		WHERE b.custid = @CustId
			AND (b.transid = @RefNo
				OR (b.refno = @RefNo
					AND sp.ProductId = 3
					AND sp.EventType = 0))
	END

	-- FROM bettrans_bk
	IF @WinLostDate IS NULL
	BEGIN
		SELECT TOP(1)
			@TransId = b.transid,
			@WinLostDate = b.winlostdate,
			@BetType = b.bettype,
			@RefNo = b.refno
		FROM DBARC.bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS sp ON b.bettype = sp.bettype
		WHERE b.custid = @CustId
			AND (b.transid = @RefNo
				OR (b.refno = @RefNo
					AND sp.ProductId = 3
					AND sp.EventType = 0))
	END

	IF @WinLostDate IS NOT NULL
	BEGIN
		-- Bettrans
		IF @WinLostDate > @MoveBetsDay
		BEGIN
			-- Number Game
			IF EXISTS (SELECT TOP(1) 1 FROM @SportBettype WHERE EventType = 1 AND Bettype = @BetType)
			BEGIN
				INSERT INTO @Data
				SELECT
					b.bettype,
					b.transid,
					ISNULL(b.betid, 0) AS BetID,
					b.refno,
					m.matchcode,
					m.eventdate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					m.homeid,
					m.awayid,
					ISNULL(b.checktime,'') settleTime,
					b.hdp1,
					b.hdp2,
					b.odds,
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
					'' AS TransDesc
				FROM
					dbo.bettrans AS b WITH (NOLOCK)
					INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
					INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
				WHERE b.transid = @TransId AND s.EventType = 1
			END

			-- Happy 5 Linked Games (bettrans)
			IF EXISTS ( SELECT TOP(1) 1 FROM @SportBettype
						WHERE Bettype = @BetType
							AND EventType = 0
							AND RefTable = 3)
			BEGIN
				INSERT INTO @Data
				SELECT
					b.bettype,
					b.transid,
					ISNULL(b.betid, 0) AS BetID,
					b.refno,
					'' AS matchcode,
					'' AS eventdate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					0 AS homeid,
					0 AS awayid,
					'' AS settleTime,
					0 AS hdp1,
					0 AS hdp2,
					b.odds AS odds,
					0 AS OddsType,
					b.status,
					'' AS comstatus,
					b.stake,
					b.actual_stake,
					b.transdate,
					'' AS betteam,
					b.spositiontaking,
					b.mpositiontaking,
					b.apositiontaking,
					0 AS liveindicator,
					0 AS modds,
					b.custid,
					0 AS livehomescore,
					0 AS liveawayscore,
					0,
					0,
					0 AS leagueid,
					b.matchid AS sporttype,
					b.ip,
					b.betfrom,
					0 AS matchid,
					CONVERT(BIT, 0) AS IsNeutral,
					(b.winlost - b.actual_stake) AS WinLost,
					b.playercomm AS commission,
					(b.scomm - b.acomm) AS scomm,
					(b.acomm - b.comm) AS acomm,
					(b.comm - b.playercomm) AS comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					'' AS showtime,
					b.winlostdate,
					ISNULL(b.betcheck, '') AS BetCheck,
					ISNULL(b.transdesc, '') AS TransDesc
				FROM dbo.bettrans AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
				WHERE b.transid = @TransId
					AND s.EventType = 0
					AND s.RefTable = 3
			END

			-- Happy 5 Linked Games (translog)
			IF EXISTS ( SELECT TOP(1) 1 FROM @SportBettype
						WHERE Bettype = @BetType
							AND EventType = 0
							AND RefTable = 3)
			BEGIN
				INSERT INTO @Data
				SELECT
					b.gameid AS BetType,
					b.translogid AS transid,
					0 AS BetID,
					b.translogid AS refno,
					'' AS matchcode,
					'' AS eventdate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					0 AS homeid,
					0 AS awayid,
					'' AS settleTime,
					0 AS hdp1,
					0 AS hdp2,
					b.odds AS odds,
					0 AS OddsType,
					b.status,
					'' AS comstatus,
					b.stake,
					b.actual_stake,
					b.transdate,
					'' AS betteam,
					b.spositiontaking,
					b.mpositiontaking,
					b.apositiontaking,
					0 AS liveindicator,
					0 AS modds,
					b.custid,
					0 AS livehomescore,
					0 AS liveawayscore,
					0,
					0,
					0 AS leagueid,
					b.productID AS sporttype,
					b.ip,
					b.betfrom,
					0 AS matchid,
					CONVERT(BIT, 0) AS IsNeutral,
					0 AS WinLost,
					0 AS commission,
					0 AS scomm,
					0 AS acomm,
					0 AS comm,
					0 AS awinlost,
					0 AS mwinlost,
					0 AS swinlost,
					'' AS showtime,
					b.winlostdate,
					ISNULL(b.GameID3rd, '') AS BetCheck,
					ISNULL(b.transdesc, '') AS TransDesc
				FROM dbo.translog AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = b.gameID
				WHERE b.translogid = @TransId
					AND s.EventType = 0
					AND s.RefTable = 3
			END
		END

		-- Bettrans14
		ELSE IF @WinLostDate <= @MoveBetsDay AND @WinLostDate >= @BalanceUpDay
		BEGIN
			-- Number Game
			IF EXISTS (SELECT TOP(1) 1 FROM @SportBettype WHERE EventType = 1 AND Bettype = @BetType)
			BEGIN
				INSERT INTO @Data
				SELECT
					b.bettype,
					b.transid,
					ISNULL(b.betid, 0) AS BetID,
					b.refno,
					m.matchcode,
					m.eventdate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					m.homeid,
					m.awayid,
					ISNULL(b.checktime,'') settleTime,
					b.hdp1,
					b.hdp2,
					b.odds,
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
					'' AS TransDesc
				FROM
					dbo.bettrans14 AS b WITH (NOLOCK)
					INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
					INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
				WHERE b.transid = @TransId AND s.EventType = 1
			END

			-- Happy 5 Linked Games
			IF EXISTS ( SELECT TOP(1) 1 FROM @SportBettype WHERE Bettype = @BetType AND EventType = 0)
			BEGIN
				INSERT INTO @Data
				SELECT
					b.bettype,
					b.transid,
					ISNULL(b.betid, 0) AS BetID,
					b.refno,
					'' AS matchcode,
					'' AS eventdate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					0 AS homeid,
					0 AS awayid,
					'' AS settleTime,
					0 AS hdp1,
					0 AS hdp2,
					b.odds AS odds,
					0 AS OddsType,
					b.status,
					'' AS comstatus,
					b.stake,
					b.actual_stake,
					b.transdate,
					'' AS betteam,
					b.spositiontaking,
					b.mpositiontaking,
					b.apositiontaking,
					0 AS liveindicator,
					0 AS modds,
					b.custid,
					0 AS livehomescore,
					0 AS liveawayscore,
					0,
					0,
					0 AS leagueid,
					b.matchid AS sporttype,
					b.ip,
					b.betfrom,
					0 AS matchid,
					CONVERT(BIT, 0) AS IsNeutral,
					(b.winlost - b.actual_stake) AS WinLost,
					b.playercomm AS commission,
					(b.scomm - b.acomm) AS scomm,
					(b.acomm - b.comm) AS acomm,
					(b.comm - b.playercomm) AS comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					'' AS showtime,
					b.winlostdate,
					ISNULL(b.betcheck, '') AS BetCheck,
					ISNULL(b.transdesc, '') AS TransDesc
				FROM dbo.bettrans14 AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
				WHERE b.transid = @TransId AND s.EventType = 0
			END
		END

		--Bettransbk
		ELSE IF @WinLostDate < @BalanceUpDay
		BEGIN
			-- Number Game
			IF EXISTS (SELECT TOP(1) 1 FROM @SportBettype WHERE EventType = 1 AND Bettype = @BetType)
			BEGIN
				INSERT INTO @Data
				SELECT
					b.bettype,
					b.transid,
					ISNULL(b.betid, 0) AS BetID,
					b.refno,
					m.matchcode,
					m.eventdate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					m.homeid,
					m.awayid,
					ISNULL(b.checktime,'') settleTime,
					b.hdp1,
					b.hdp2,
					b.odds,
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
					'' AS TransDesc
				FROM DBARC.bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK)
					INNER JOIN DBARC.bodb_Archive.dbo.match_bk AS m WITH (NOLOCK) ON b.matchid = m.matchid
					INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
				WHERE b.transid = @TransID AND s.EventType = 1
			END

			-- Happy 5 Linked Games
			IF EXISTS ( SELECT TOP(1) 1 FROM @SportBettype WHERE Bettype = @BetType AND EventType = 0)
			BEGIN
				INSERT INTO @Data
				SELECT
					b.bettype,
					b.transid,
					ISNULL(b.betid, 0) AS BetID,
					b.refno,
					'' AS matchcode,
					'' AS eventdate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					0 AS homeid,
					0 AS awayid,
					'' AS settleTime,
					0 AS hdp1,
					0 AS hdp2,
					b.odds AS odds,
					0 AS OddsType,
					b.status,
					'' AS comstatus,
					b.stake,
					b.actual_stake,
					b.transdate,
					'' AS betteam,
					b.spositiontaking,
					b.mpositiontaking,
					b.apositiontaking,
					0 AS liveindicator,
					0 AS modds,
					b.custid,
					0 AS livehomescore,
					0 AS liveawayscore,
					0,
					0,
					0 AS leagueid,
					b.matchid AS sporttype,
					b.ip,
					b.betfrom,
					0 AS matchid,
					CONVERT(BIT, 0) AS IsNeutral,
					(b.winlost - b.actual_stake) AS WinLost,
					b.playercomm AS commission,
					(b.scomm - b.acomm) AS scomm,
					(b.acomm - b.comm) AS acomm,
					(b.comm - b.playercomm) AS comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					'' AS showtime,
					b.winlostdate,
					ISNULL(b.betcheck, '') AS BetCheck,
					ISNULL(b.transdesc, '') AS TransDesc
				FROM DBARC.bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
				WHERE b.transid = @TransId AND s.EventType = 0
			END
		END
	END

	SELECT b.*,
		ex.currency
	FROM @Data AS b
		LEFT JOIN dbo.custInfo AS ci WITH (NOLOCK) ON b.CustId = ci.custid
		LEFT JOIN dbo.Exchange AS ex WITH (NOLOCK) ON ci.currency = ex.exchangeid
	ORDER BY b.TransId
END
GO
