/*<info serverAlias="DBSIG-bodb02" executers="bodbAdminNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[SiteDB_Acc_BetList_SelByRefNo_Mem]
	@CustId			INT,
	@RefNo			BIGINT,
	@MoveBetsDay	SMALLDATETIME,
	@BalanceUpDay	SMALLDATETIME,
	@IsCN88			BIT = 0
AS

/*
	Created by: 20220729@Kos
	Task: NAP - Left Panel - Bet List By Refno - SiteDB
	DB: DBSIG.bodb02

	Revisions:
		- 20220729@Kos: Scale out DBTRANS [Redmine: #175253]
		- 20220825@Razor: Support SEAL Entertainment [Redmine: #176210]
		- 20220909@Razor: Support Microgaming RNG Casino [Redmine: #175851]
		- 20221117@Razor: Support Player Tips [Redmine: #180590]
		- 20230206@Razor: Support Jili [Redmine: #182864]
		- 20230417@Razor: Remove Betfrom column [Redmine: #126137]
		- 20230526@Razor: Support YeeBet [Redmine: #186547]
		- 20230727@Razor: Support Virtual Sports 3 [Redmine: #189205]
		- 20230909@Razor: Remove GDG, Fishing World products [Redmine: #174511]
		- 20230909@Razor: Remove GD, Colossusbet products [Redmine: #179132]
		- 20231005@Kos: Support Parlay Boost [Redmine: #194992]		
		- 20231020@Razor: Support show max payout [Redmine: #194491]
					- Return new JackpotInfo column
					- Return ExtraInfo for show Max Payout
*/

BEGIN
	SET NOCOUNT ON

	-- List of bettype not allowed to delete
	DECLARE @tableBettypeNotAllowDelete TABLE(typeid INT NOT NULL)

	INSERT INTO @tableBettypeNotAllowDelete (typeid)
	SELECT 31 UNION ALL SELECT 32 UNION ALL SELECT 33 UNION ALL SELECT 41 UNION ALL SELECT 42 UNION ALL SELECT 43 UNION ALL
	SELECT 51 UNION ALL SELECT 52 UNION ALL SELECT 53 UNION ALL SELECT 54 UNION ALL SELECT 55 UNION ALL SELECT 56 UNION ALL
	SELECT 61 UNION ALL SELECT 62 UNION ALL SELECT 63 UNION ALL SELECT 64 UNION ALL SELECT 65 UNION SELECT 66

	DECLARE @Data TABLE (
		BetType				INT,
		TransId				BIGINT,
		BetId				BIGINT,
		RefNo				NVARCHAR(50),
		MatchCode			NVARCHAR(1000),
		Race				NVARCHAR(20),
		EventDate			DATETIME,
		VirtualRate			FLOAT,
		IsShowOTExRate		BIT,
		SDiscount			SMALLMONEY,
		ADiscount			SMALLMONEY,
		Discount			SMALLMONEY,
		PlayerDiscount		SMALLMONEY,
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
		SettlementStatus	TINYINT,
		ComStatus			NVARCHAR(50),
		Stake				MONEY,
		Actual_Stake		MONEY,
		TransDate			DATETIME,
		BetTeam				NVARCHAR(100),
		SPositionTaking		SMALLMONEY,
		MPositionTaking		SMALLMONEY,
		APositionTaking		SMALLMONEY,
		SPositionTaking2	SMALLMONEY,
		MPositionTaking2	SMALLMONEY,
		APositionTaking2	SMALLMONEY,
		LiveIndicator		BIT,
		Modds				MONEY,
		CustId				INT,
		LiveHomeScore		INT,
		LiveAwayScore		INT,
		FinalHomeScore		INT,
		FinalAwayScore		INT,
		LeagueId			INT,
		SportType			SMALLINT,
		Ip					VARCHAR(45),
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
		BetCheck			NVARCHAR(2000),
		TransDesc			NVARCHAR(1000),
		OddsSpread			MONEY,
		OriginalBetType		INT,
		BetdaqId			BIGINT,
		ExtraInfo			VARCHAR(1000),
		JackpotInfo			VARCHAR(50),
		WalletType			TINYINT,
		RefCode				BIGINT,
		CurrencyId			TINYINT,
		SiteId				VARCHAR(20)
	)

	DECLARE @TransId	BIGINT,
		@WinLostDate	SMALLDATETIME,
		@BetType		INT

	-- Get Sport Bettype Matrix
	DECLARE @SportBettype TABLE (ProductID TINYINT, Bettype SMALLINT, EventType TINYINT, SubProduct VARCHAR(500))

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype
	SELECT ProductID, BetType, EventType, SubProduct
	FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest)
	WHERE BetType NOT IN (903, 904, 913, 914, 999)
		AND ProductID NOT IN (2, 4, 7, 9, 13, 17, 19, 26, 30, 31, 33)

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
		AND ( sp.productid IN (8, 28, 38, 40, 43, 49, 63)
			OR sp.bettype BETWEEN 801 AND 899
			OR (sp.ProductId = 3 AND sp.EventType = 0))

	-- FROM bettrans
	IF @WinLostDate IS NULL
	BEGIN
		SELECT TOP(1)
			@TransId = b.transid,
			@WinLostDate = b.winlostdate,
			@BetType = b.bettype,
			@RefNo = b.refno
		FROM dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS sp ON b.bettype = sp.bettype
		WHERE b.custid = @CustId
			AND ( b.transid = @RefNo
				OR ( b.refno = @RefNo
					AND (sp.productid IN (8, 28, 38, 40, 43, 49, 63)
						OR sp.bettype BETWEEN 801 AND 899
						OR (sp.productid = 3 AND sp.EventType = 0))))
			--exclude metric gaming running ticket
			AND (b.bettype NOT BETWEEN 801 AND 806
				OR (b.bettype BETWEEN 801 AND 806 AND b.statusID NOT IN (0, 1)))
	END

	IF @WinLostDate IS NOT NULL
	BEGIN
		-- Bettrans
		IF @WinLostDate > @MoveBetsDay
		BEGIN
			-- Sportbooks, Number Game, Virtual Sports, BetRadar Virtual Sports, Cash Out, Virtual Sports 3
			IF EXISTS (SELECT TOP(1) 1 FROM @SportBettype WHERE EventType = 1 AND bettype = @BetType )
			BEGIN
				INSERT INTO @Data
				SELECT
					b.bettype,
					b.transid,
					ISNULL(b.betid, 0) AS BetID,
					b.refno,
					m.matchcode,
					'' AS race,
					CASE
						WHEN s.ProductID IN (1, 25) THEN m.GlobalShowTime
						ELSE m.eventdate
					END AS EventDate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					b.playerdiscount,
					m.homeid,
					m.awayid,
					ISNULL(b.checktime,'') AS settleTime,
					b.hdp1,
					b.hdp2,
					b.odds,
					0 finalodds,
					0 finalodds2,
					b.OddsType,
					CASE
						WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
						WHEN @IsCN88 = 1 AND s.ProductID IN (1, 5, 27) AND b.status = 'Won' AND b.modds = 0.25 THEN 'Half Won'
						WHEN @IsCN88 = 1 AND s.ProductID IN (1, 5, 27) AND b.status = 'Lose' AND b.modds = -0.25 THEN 'Half Lose'
						ELSE b.status
					END AS status,
					ISNULL(m.SettlementStatus, 0) AS SettlementStatus,
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
					b.matchid,
					ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
					CASE 
						WHEN b.bettype IN (SELECT typeid FROM @tableBettypeNotAllowDelete)
							OR b.statusID NOT IN (0, 1, 112, 113, 111) THEN 0
						ELSE 1
					END AS allowdelete,
					(b.winlost - b.actual_stake) AS WinLost,
					b.playercomm AS commission,
					(b.scomm - b.acomm) AS scomm,
					(b.acomm - b.comm) AS acomm,
					(b.comm - b.playercomm) AS comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					CASE
						WHEN s.ProductID IN (5, 27) THEN CONVERT(NVARCHAR(50), m.kickofftime)
						ELSE m.showtime
					END AS ShowTime,
					b.winlostdate,
					b.BetCheck,
					ISNULL(b.transdesc, '') AS transdesc,
					ISNULL(b.oddsspread, 0) AS OddsSpread,	-- For Myanmar Odds
					0 AS OriginalBetType,
					CASE
						WHEN s.ProductID = 1 THEN ISNULL(b.betdaqid, -1)
						ELSE -1
					END AS BetdaqId,
					ISNULL(b.ExtraInfo, '') AS ExtraInfo,
					'' AS JackpotInfo,
					CASE
						WHEN s.ProductID = 1 THEN ISNULL(b.WalletType, 0)
						ELSE 0
					END AS WalletType,
					CASE
						WHEN s.ProductID = 1 THEN ISNULL(b.RefCode, 0)
						ELSE 0
					END AS RefCode,
					b.currency,
					'' AS SiteId
				FROM
					dbo.bettrans AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
					INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
				WHERE b.transid = @TransId AND s.EventType = 1

				UNION ALL -- translog metric gaming
				SELECT
					b.gameid AS BetType,
					b.translogid AS transid,
					0 AS BetID,
					b.translogid AS refno,
					m.matchcode,
					'' AS race,
					m.GlobalShowTime AS EventDate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					b.playerdiscount,
					m.homeid,
					m.awayid,
					'' AS settleTime,
					0 AS hdp1,
					0 AS hdp2,
					b.odds,
					0 finalodds,
					0 finalodds2,
					CASE
						WHEN b.gameid IN (801, 803, 804, 805, 806) THEN CONVERT(TINYINT, ISNULL(b.custom1, 0))
						ELSE 0
					END AS OddsType,
					b.status,
					ISNULL(m.SettlementStatus, 0) AS SettlementStatus,
					0 AS comstatus,
					b.stake,
					b.actual_stake,
					b.transdate,
					'' AS betteam,
					b.spositiontaking,
					b.mpositiontaking,
					b.apositiontaking,
					0 spositiontaking2,
					0 mpositiontaking2,
					0 apositiontaking2,
					0 AS liveindicator,
					0 AS modds,
					b.custid,
					0 AS livehomescore,
					0 AS liveawayscore,
					m.finalhomescore,
					m.finalawayscore,
					m.leagueid,
					m.sporttype,
					b.ip,
					b.eventID,
					ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
					CASE
						WHEN b.gameID IN (SELECT typeid FROM @tableBettypeNotAllowDelete)
							OR b.statusID NOT IN (0, 1, 112, 113, 111) THEN 0
						ELSE 1
					END AS allowdelete,
					0 AS WinLost,
					0 AS commission,
					0 AS scomm,
					0 AS acomm,
					0 AS comm,
					0 AS awinlost,
					0 AS mwinlost,
					0 AS swinlost,
					m.showtime,
					b.winlostdate,
					'' AS BetCheck,
					b.transdesc,
					0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					'' AS ExtraInfo,
					'' AS JackpotInfo,
					0 AS WalletType,
					0 AS RefCode,
					b.currency,
					b.SiteId
				FROM
					dbo.translog AS b WITH (NOLOCK) 
					INNER JOIN @SportBettype s ON s.Bettype = b.gameid
					INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.eventid = m.matchid
				WHERE
					s.Bettype BETWEEN 801 AND 899
					AND b.translogid = @TransId
					AND b.statusID IN (0, 1)

				-- Get more info for BetTrade tickets
				IF EXISTS (SELECT TOP(1) 1 FROM @Data WHERE SportType = 1 AND BetType = 901)
				BEGIN
					UPDATE b
					SET b.Odds = ob.odds,
						b.Stake = ob.stake,
						b.LiveHomeScore = ob.livehomescore,
						b.LiveAwayScore = ob.liveawayscore,
						b.BetId = ob.bettype
					FROM @Data AS b
						INNER JOIN dbo.bettrans AS ob WITH (NOLOCK) ON b.RefNo = ob.transid
					WHERE b.SportType = 1 AND b.BetType = 901
				END

				IF EXISTS (SELECT TOP(1) 1 FROM @Data WHERE SportType = 1 AND BetType = 902)
				BEGIN
					UPDATE b
					SET b.Odds = ob.odds,
						b.Stake = ob.stake,
						b.LiveHomeScore = ob.livehomescore,
						b.LiveAwayScore = ob.liveawayscore,
						b.Comm = ISNULL(cb.awinlost, 0),
						b.BetId = ob.bettype
					FROM @Data AS b
						INNER JOIN dbo.bettrans AS ob WITH (NOLOCK) ON b.RefNo = ob.transid
						LEFT JOIN dbo.bettrans AS cb WITH (NOLOCK)
							ON b.RefNo = cb.RefNo
							AND cb.BetType = 903
							AND cb.custid = @CustId
							AND cb.winlostdate = @WinLostDate
					WHERE b.SportType = 1 AND b.BetType = 902
				END

				-- Get more info for CashOut tickets
				IF EXISTS (SELECT TOP(1) 1 FROM @Data WHERE BetType = 911)
				BEGIN
					UPDATE b
					SET b.Odds = ob.odds,
						b.LiveIndicator = ob.liveindicator,
						b.LiveHomeScore = ob.livehomescore,
						b.LiveAwayScore = ob.liveawayscore,
						b.OriginalBetType = ob.bettype,
						b.BetdaqId = ob.transid
					FROM @Data AS b
						INNER JOIN dbo.bettrans AS ob WITH (NOLOCK) ON b.RefNo = ob.transid
					WHERE b.BetType = 911
				END

				IF EXISTS (SELECT TOP(1) 1 FROM @Data WHERE BetType = 912)
				BEGIN
					UPDATE b
					SET b.Odds = ob.odds,
						b.LiveIndicator = ob.liveindicator,
						b.LiveHomeScore = ob.livehomescore,
						b.LiveAwayScore = ob.liveawayscore,
						b.OriginalBetType = ob.bettype,
						b.BetdaqId = ob.transid,
						b.Stake = cob.stake,
						b.Comm = ISNULL(cb.AWinLost, 0)
					FROM @Data AS b
						INNER JOIN dbo.bettrans AS cob WITH (NOLOCK) ON b.RefNo = cob.transid
						INNER JOIN dbo.bettrans AS ob WITH (NOLOCK) ON cob.RefNo = ob.transid
						LEFT JOIN dbo.bettrans AS cb WITH (NOLOCK)
							ON b.RefNo = cb.RefNo
							AND cb.BetType = 913
							AND cb.custid = @CustId
							AND cb.winlostdate = @WinLostDate
					WHERE b.BetType = 912
				END
			END

			-- Mix Parlay, System Parlay, Mix Parlay (Betradar Virtual Sports)
			IF @BetType IN (9, 29, 2799)
			BEGIN
				INSERT INTO @Data
				SELECT
					b.bettype,
					CASE
						WHEN (b.bettype = 29 AND ISNULL(b.betid, 0) > 0) THEN b.betid
						ELSE b.transid
					END AS transid,
					ISNULL(b.betid, 0) AS BetID,
					b.refno,
					'' matchcode,
					'' AS race,
					'' AS eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					b.playerdiscount,
					0 AS homeid,
					0 AS awayid,
					'' settleTime,
					b.hdp1,
					b.hdp2,
					b.odds,
					0 finalodds,
					0 finalodds2,
					0 AS OddsType,
					CASE
						WHEN b.status = 'running' THEN
							CASE
								WHEN EXISTS (SELECT 1 FROM dbo.bettransm AS bm WITH (NOLOCK)
											WHERE bm.custid = b.custid
												AND bm.refno = b.refno
												AND (bm.status = 'waiting'
													OR (bm.status = 'running' AND ISNULL(bm.SecAcceptFlag, 0) = 1 AND ISNULL(bm.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP)))
									THEN 'Waiting'
								ELSE b.status
							END
						ELSE b.status
					END AS Status,
					0 AS SettlementStatus,
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
					0 liveindicator,
					b.modds,
					b.custid,
					b.livehomescore,
					b.liveawayscore,
					0,
					0,
					0 AS leagueid,
					0 AS sporttype,
					b.ip,
					0 matchid,
					CONVERT(BIT,0) AS IsNeutral,
					0 AS allowdelete,
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
					'' AS transdesc,
					ISNULL(b.oddsspread, 0) AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					b.ExtraInfo,
					'' AS JackpotInfo,
					0 AS WalletType,
					0 AS RefCode,
					b.currency,
					'' AS SiteId
				FROM dbo.bettrans AS b WITH (NOLOCK)
				WHERE
					b.matchid IN (9, 29, 2799)
					AND b.bettype IN (9, 29, 2799)
					AND b.transid = @TransId
			END

			-- Keno, Lottery, NPH Promotion, Virtual Games, Table Games, Indo 4D, BBIN, Leap Gaming Virtual Sports, Happy 5 Linked Games(Number Game)
			-- Sports Lottery, Player Tips
			IF EXISTS ( SELECT TOP(1) 1 FROM @SportBettype
						WHERE Bettype = @BetType AND (ProductID IN (8, 28, 37, 38, 40, 43, 47, 49, 63, 74) OR (ProductID = 3 AND EventType = 0)))
			BEGIN
				INSERT INTO @Data
				SELECT
					b.bettype,
					b.transid,
					ISNULL(b.betid, 0) AS BetID,
					b.refno,
					'' AS matchcode,
					'' AS race,
					'' AS eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					b.playerdiscount,
					0 AS homeid,
					0 AS awayid,
					'' AS settleTime,
					0 AS hdp1,
					0 AS hdp2,
					CASE
						WHEN s.ProductID IN (3, 8, 28, 38, 40, 43, 49, 63) THEN b.odds
						ELSE 0
					END AS odds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS OddsType,
					CASE
						WHEN s.ProductID = 40 AND b.status = 'Won' AND b.modds = 0.25 THEN 'Half Won'
						WHEN s.ProductID = 40 AND b.status = 'Lose' AND b.modds = -0.25 THEN 'Half Lose'
						ELSE b.status
					END AS status,
					0 AS SettlementStatus,
					'' AS comstatus,
					b.stake,
					b.actual_stake,
					b.transdate,
					'' AS betteam,
					b.spositiontaking,
					b.mpositiontaking,
					b.apositiontaking,
					0 AS spositiontaking2,
					0 AS mpositiontaking2,
					0 AS apositiontaking2,
					0 AS liveindicator,
					0 AS modds,
					b.custid,
					0 AS livehomescore,
					0 AS liveawayscore,
					0,
					0,
					0 AS leagueid,
					CASE
						WHEN s.ProductID = 8 THEN 202
						WHEN s.ProductID = 28 THEN 220
						WHEN s.ProductID IN (3, 37, 38, 40, 43, 47, 49, 63, 74) THEN b.matchid
						ELSE 0
					END AS sporttype,
					b.ip,
					CASE
						WHEN s.ProductID = 74 THEN ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p74/@m)[1]','INT'), 0)
						ELSE 0
					END AS matchid,
					CONVERT(BIT, 0) AS IsNeutral,
					0 AS allowdelete,
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
					CASE
						WHEN s.ProductID IN (3, 38, 63) THEN b.betcheck
						WHEN s.ProductId = 8 THEN ISNULL(b.comstatus, '')
						ELSE ''
					END AS BetCheck,
					CASE
						WHEN s.ProductID IN (3, 8, 28, 38, 40, 43, 49, 63) THEN b.transdesc
						ELSE ''
					END AS transdesc,
					0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					ISNULL(b.ExtraInfo, '') AS ExtraInfo,
					'' AS JackpotInfo,
					0 AS WalletType,
					0 AS RefCode,
					b.currency,
					CASE 
						WHEN s.ProductId = 3 AND s.EventType = 0 THEN CONVERT(VARCHAR(20), b.betdaqid)
						WHEN s.ProductId IN (38, 63) THEN CONVERT(VARCHAR(20), b.betdaqid)
						ELSE '' 
					END AS SiteId
				FROM dbo.bettrans AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
				WHERE b.transid = @TransId
					AND (s.ProductId IN (8, 28, 37, 38, 40, 43, 47, 49, 63, 74)
							OR (s.ProductId = 3 AND s.EventType = 0))

				-- Get match info for Player Tips
				IF EXISTS (SELECT 1 FROM @Data WHERE SportType = 157)
				BEGIN
					UPDATE b
					SET
						LeagueId = m.leagueid,
						HomeId = m.homeid,
						AwayId = m.awayid,
						EventDate = m.GlobalShowTime
					FROM @Data AS b
						INNER JOIN dbo.match AS m WITH (NOLOCK) ON m.matchid = b.MatchId
					WHERE b.SportType = 157
				END
			END

			-- NG2
			IF EXISTS (SELECT TOP(1) 1 FROM @SportBettype WHERE ProductID = 23 AND bettype = @BetType)
			BEGIN
				INSERT INTO @Data
				SELECT
					b.bettype,
					b.transid,
					ISNULL(b.betid, 0) AS BetId,
					b.refno,
					'' AS matchcode,
					'' AS race,
					'' AS eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					b.playerdiscount,
					0 AS homeid,
					0 AS awayid,
					'' AS settleTime,
					b.hdp1,
					b.hdp2,
					b.odds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS OddsType,
					b.status,
					0 AS SettlementStatus,
					CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					b.stake,
					b.actual_stake,
					b.transdate,
					'' AS betteam,
					b.spositiontaking,
					b.mpositiontaking,
					b.apositiontaking,
					0 AS spositiontaking2,
					0 AS mpositiontaking2,
					0 AS apositiontaking2,
					0 AS liveindicator,
					0 AS modds,
					b.custid,
					b.livehomescore,
					0 AS liveawayscore,
					0,
					0,
					0 AS leagueid,
					CASE
						WHEN s.Bettype BETWEEN 2501 AND 2539 THEN 213
						WHEN s.Bettype BETWEEN 2541 AND 2579 THEN 214
						WHEN s.Bettype BETWEEN 2581 AND 2619 THEN 215
						WHEN s.Bettype BETWEEN 2621 AND 2659 THEN 216
						WHEN s.Bettype BETWEEN 2681 AND 2699 THEN 218
						ELSE 0
					END AS sporttype,
					b.ip,
					b.betdaqid AS matchid,
					CONVERT(BIT, 0) AS IsNeutral,
					0 AS allowdelete,
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
					'' AS BetCheck,
					ISNULL(b.transdesc, '') AS transdesc,
					0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					'' AS ExtraInfo,
					'' AS JackpotInfo,
					0 AS WalletType,
					0 AS RefCode,
					b.currency,
					'' AS SiteId
				FROM dbo.bettrans AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
				WHERE b.transid = @TransId
					AND s.ProductId = 23
			END

			-- Outright
			IF @BetType = 10
			BEGIN
				INSERT INTO @Data
				SELECT
					b.bettype,
					b.transid,
					ISNULL(b.betid, 0) AS BetID,
					b.refno,
					odds.matchcode,
					odds.groupmatch AS race,
					odds.eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					b.playerdiscount,
					0 AS homeid,
					odds.teamid AS awayid,
					'' AS settleTime,
					b.hdp1,
					b.hdp2,
					b.odds,
					0 AS finalodds,
					0 AS finalodds2,
					b.oddstype AS OddsType,
					b.status,
					0 AS SettlementStatus,
					CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					b.stake,
					b.actual_stake,
					b.transdate,
					b.betteam,
					b.spositiontaking,
					b.mpositiontaking,
					b.apositiontaking,
					0 AS spositiontaking2,
					0 AS mpositiontaking2,
					0 AS apositiontaking2,
					b.liveindicator,
					b.modds,
					b.custid,
					b.livehomescore,
					b.liveawayscore,
					0,
					0,
					odds.leagueid,
					l.sporttype,
					b.ip,
					b.matchid,
					CONVERT(BIT,0) AS IsNeutral,
					CASE
						WHEN b.bettype IN (SELECT typeid FROM @tableBettypeNotAllowDelete)
							OR b.statusID NOT IN (0, 1, 112, 113, 111) THEN 0
						ELSE 1
					END AS allowdelete,
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
					b.BetCheck,
					'' AS transdesc,
					0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					'' AS ExtraInfo,
					'' AS JackpotInfo,
					0 AS WalletType,
					0 AS RefCode,
					b.currency,
					'' AS SiteId
				FROM dbo.bettrans AS b WITH (NOLOCK)
					INNER JOIN dbo.outright AS odds WITH (NOLOCK) ON b.matchid = odds.orid
					INNER JOIN dbo.league l WITH (NOLOCK) ON odds.leagueid = l.leagueid
				WHERE b.bettype = 10
					AND b.transid = @TransId
			END

			-- Virtual Horse Racing
			IF EXISTS (SELECT TOP(1) 1 FROM @SportBettype WHERE ProductID = 5 AND EventType = 3 AND bettype = @BetType)
			BEGIN
				INSERT INTO @Data
				SELECT
					b.bettype,
					b.transid,
					'' AS BetID,
					b.refno,
					o.RacerNum matchcode, --Horse Number
					b.oddsid AS Race, --Outright ID
					'' eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					b.playerdiscount,
					o.RacerID AS homeID,
					0 AS awayID,
					'' settleTime,
					b.hdp1,
					b.hdp2,
					b.odds,
					0 finalodds,
					0 finalodds2,
					b.OddsType,
					b.status,
					0 AS SettlementStatus,
					CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					b.stake,
					b.actual_stake,
					b.transdate,
					'' betteam,
					CASE WHEN b.bettype = 1233 THEN bm.spositiontaking ELSE b.spositiontaking END,
					CASE WHEN b.bettype = 1233 THEN bm.mpositiontaking ELSE b.mpositiontaking END,
					CASE WHEN b.bettype = 1233 THEN bm.apositiontaking ELSE b.apositiontaking END,
					CASE WHEN b.bettype = 1233 THEN bm.spositiontaking2 ELSE 0 END,
					CASE WHEN b.bettype = 1233 THEN bm.mpositiontaking2 ELSE 0 END,
					CASE WHEN b.bettype = 1233 THEN bm.apositiontaking2 ELSE 0 END,
					0 liveindicator,
					b.modds,
					b.custid,
					b.livehomescore,
					b.liveawayscore,
					0 finalhomescore,
					0 finalawayscore,
					r.leagueid,
					r.sporttype,
					b.ip,
					b.matchid,
					CONVERT(BIT, 0) AS IsNeutral,
					CASE 
						WHEN b.bettype IN (SELECT typeid FROM @tableBettypeNotAllowDelete)
							OR statusID NOT IN (0, 1, 112, 113, 111) THEN 0 
						ELSE 1 
					END AS allowdelete,
					(b.winlost - b.actual_stake) winlost,
					b.playercomm AS commission,
					(b.scomm - b.acomm) AS scomm,
					(b.acomm - b.comm) AS acomm,
					(b.comm - b.playercomm) AS comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					r.EventTime AS showtime,
					b.winlostdate,
					b.BetCheck,
					'' AS transdesc,
					0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					'' AS ExtraInfo,
					'' AS JackpotInfo,
					0 AS WalletType,
					0 AS RefCode,
					b.currency,
					'' AS SiteId
				FROM 
					dbo.bettrans AS b WITH (NOLOCK)
					INNER JOIN dbo.VSOutright AS o WITH (NOLOCK) ON b.oddsid = o.Orid
					INNER JOIN dbo.VSRaceInfo AS r WITH (NOLOCK) ON r.EventID = o.EventID
					INNER JOIN @SportBettype AS s ON s.BetType = b.BetType 
					LEFT JOIN (
						SELECT
							t.refno,
							t.apositiontaking,
							t.mpositiontaking,
							t.spositiontaking,
							f.apositiontaking apositiontaking2,
							f.mpositiontaking mpositiontaking2,
							f.spositiontaking spositiontaking2
						FROM dbo.bettransm AS t WITH (NOLOCK)
							INNER JOIN dbo.bettransm AS f WITH (NOLOCK) ON t.refno = f.refno
						WHERE t.bettype = 1231 AND f.bettype = 1232
						) bm ON b.refno = bm.refno
				WHERE
					b.transid = @TransId
					AND s.ProductID = 5
					AND s.EventType = 3
			END

			-- Bitcoin
			IF EXISTS (SELECT TOP(1) 1 FROM @SportBettype WHERE ProductID = 69 AND bettype = @BetType )
			BEGIN
				INSERT INTO @Data
				SELECT
					b.bettype,
					b.transid,
					0 AS BetID,
					b.refno,
					'' matchcode,
					'' AS race,
					m.EndTime AS EventDate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					b.playerdiscount,
					m.homeid,
					m.awayid,
					'' AS settleTime,
					b.hdp1,
					0 hdp2,
					b.odds,
					0 finalodds,
					0 finalodds2,
					b.OddsType,
					b.status,
					0 SettlementStatus,
					0 AS comstatus,
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
					0 liveindicator,
					0 modds,
					b.custid,
					0 livehomescore,
					0 liveawayscore,
					0 finalhomescore,
					0 finalawayscore,
					0 leagueid,
					m.sporttype,
					b.ip,
					b.matchid,
					0 IsNeutral,
					0 AS allowdelete,
					(b.winlost - b.actual_stake) AS WinLost,
					b.playercomm AS commission,
					(b.scomm - b.acomm) AS scomm,
					(b.acomm - b.comm) AS acomm,
					(b.comm - b.playercomm) AS comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					'' AS ShowTime,
					b.winlostdate,
					'' BetCheck,
					'' AS transdesc,
					0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					b.ExtraInfo,
					'' AS JackpotInfo,
					0 AS WalletType,
					0 AS RefCode,
					b.currency,
					'' AS SiteId
				FROM
					dbo.bettrans AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
					INNER JOIN dbo.match3rd AS m WITH (NOLOCK) ON b.matchid = m.match3rdid
				WHERE b.transid = @TransId
			END

			-- Keno, Lottery, Virtual Games, Table Games, Indo 4D, Leap Gaming Virtual Sports, Happy 5 Linked Games(Number Game), Sports Lottery (translog)
			IF EXISTS (SELECT TOP(1) 1 FROM @SportBettype
						WHERE (ProductID IN (8, 28, 38, 40, 43, 49, 63) OR (ProductID = 3 AND EventType = 0)) AND Bettype = @BetType )
			BEGIN
				INSERT INTO @Data
				SELECT
					b.gameid AS BetType,
					b.translogid AS transid,
					0 AS betid,
					b.translogid AS refno,
					'' AS matchcode,
					'' AS race,
					'' AS eventdate,
					0,
					0,
					b.sdiscount,
					b.adiscount,
					b.discount,
					b.playerdiscount,
					0 AS homeid,
					0 AS awayid,
					'' AS settleTime,
					0 AS hdp1,
					0 AS hdp2,
					CASE
						WHEN s.ProductID IN (3, 8, 28, 38, 40, 43, 49, 63) THEN b.odds
						ELSE 0
					END AS odds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS OddsType,
					b.status,
					0 AS SettlementStatus,
					0 AS comstatus,
					b.stake,
					b.actual_stake,
					b.transdate,
					'' AS betteam,
					b.spositiontaking,
					b.mpositiontaking,
					b.apositiontaking,
					0 AS spositiontaking2,
					0 AS mpositiontaking2,
					0 AS apositiontaking2,
					0 AS liveindicator,
					0 AS modds,
					b.custid,
					0 AS livehomescore,
					0 AS liveawayscore,
					0 AS finalhomescore,
					0 AS finalawayscore,
					0 AS leagueid,
					CASE
						WHEN s.ProductID = 8 THEN 202
						WHEN s.ProductID = 28 THEN 220
						WHEN s.ProductID IN (3, 38, 40, 43, 49, 63) THEN b.productID
						ELSE 0
					END AS sporttype,
					b.ip,
					0 AS MatchId,
					CONVERT(BIT, 0) AS IsNeutral,
					0 AS allowdelete,
					(-b.actual_stake) AS WinLost,
					0 AS commission,
					0,
					0,
					0,
					0,
					0,
					0,
					'' AS showtime,
					b.winlostdate,
					CASE
						WHEN s.ProductID IN (3, 38, 63) THEN b.GameID3rd
						WHEN s.ProductId = 8 THEN ISNULL(b.custom2, '')
						WHEN s.ProductId = 49 THEN ISNULL(b.custom1, '')
						ELSE ''
					END AS BetCheck,
					CASE
						WHEN s.ProductID IN (3, 8, 28, 38, 40, 43, 49, 63) THEN b.transdesc
						ELSE ''
					END AS transdesc,
					0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					'' AS ExtraInfo,
					'' AS JackpotInfo,
					0 AS WalletType,
					0 AS RefCode,
					b.currency,
					b.SiteId
				FROM dbo.translog AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = b.gameID
				WHERE b.translogid = @TransId
					AND (s.ProductID IN (8, 28, 38, 40, 43, 49, 63)
							OR (s.ProductID = 3 AND s.EventType = 0))
					AND b.statusID IN (0, 1)
			END

			-- RNG Casino Single Wallet, Voidbridge, Pragmatic Casino, Card Club, Spadegaming, Saba.club, RNG War, PG Soft, Joker, MaxGame, Habanero, CG, VGaming
			-- AdvantPlay, AdvantPlay Mini, SEAL, MG RNGCasino, Jili
			IF EXISTS (	SELECT TOP(1) 1 FROM @SportBettype
						WHERE Bettype = @BetType
							AND (ProductID IN (22, 32, 34, 36, 42, 50, 55, 56, 60, 61, 62, 66, 67, 68, 72, 73, 75)
								OR (ProductID = 6 AND SubProduct <> '')))
			BEGIN
				IF @WinLostDate >= DATEADD(DAY, DATEDIFF(DAY, 1, GETDATE()), 0)	-- yesterday and later
				BEGIN
					-- Yesterday and later running ticket
					INSERT INTO @Data
					SELECT
						b.bettype,
						b.transid,
						ISNULL(b.betid, 0) AS BetID,
						b.refno,
						'' AS matchcode,
						'' AS race,
						'' AS eventdate,
						0 AS virtualrate,
						0 AS isShowOTExRate,
						AVG(brng.sdiscount) AS sdiscount,
						AVG(brng.adiscount) AS adiscount,
						AVG(brng.discount) AS discount,
						AVG(brng.playerdiscount) AS playerdiscount,
						0 AS homeid,
						0 AS awayid,
						'' AS settleTime,
						0 AS hdp1,
						0 AS hdp2,
						0 AS odds,
						0 AS finalodds,
						0 AS finalodds2,
						0 AS OddsType,
						'Running' AS Status,
						0 AS SettlementStatus,
						CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
						SUM(brng.stake) AS stake,
						SUM(brng.actual_stake) AS actual_stake,
						b.transdate,
						'' AS betteam,
						AVG(brng.spositiontaking) AS spositiontaking,
						AVG(brng.mpositiontaking) AS mpositiontaking,
						AVG(brng.apositiontaking) AS apositiontaking,
						0 AS spositiontaking2,
						0 AS mpositiontaking2,
						0 AS apositiontaking2,
						0 AS liveindicator,
						0 AS modds,
						b.custid,
						0 AS livehomescore,
						0 AS liveawayscore,
						0,
						0,
						0 AS leagueid,
						CASE
							WHEN s.ProductID = 22 THEN 212
							WHEN s.ProductID = 32 THEN 248
							ELSE b.matchid
						END AS Sporttype,
						b.ip,
						0 AS matchid,
						CONVERT(BIT, 0) AS IsNeutral,
						0 AS allowdelete,
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
						'' AS BetCheck,
						CASE
							WHEN s.ProductID IN (6, 22, 32, 34, 36, 55, 56, 61, 62, 67, 68) THEN b.transdesc
							ELSE ''
						END AS transdesc,
						0 AS OddsSpread,
						0 AS OriginalBetType,
						-1 AS BetdaqId,
						'' AS ExtraInfo,
						'' AS JackpotInfo,
						0 AS WalletType,
						0 AS RefCode,
						0 AS currencyId,
						'' AS SiteId
					FROM dbo.bettransRnG AS brng WITH (NOLOCK)
						INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON brng.RefNo = b.transid
						INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
					WHERE
						b.transid = @TransId
						AND (s.ProductId IN (22, 32, 34, 36, 42, 50, 55, 56, 60, 61, 62, 66, 67, 68, 72, 73, 75)
							OR (s.ProductId = 6 AND s.SubProduct <> ''))
						AND brng.statusid IN (0, 1)
					GROUP BY
						b.transid,
						ISNULL(b.betid, 0),
						b.Bettype,
						b.refno,
						b.transdate,
						b.winlostdate,
						b.custid,
						b.ip,
						b.Username,
						b.comstatus,
						b.matchid,
						b.transdesc,
						s.ProductID

					-- Yesterday and today settled ticket
					INSERT INTO @Data
					SELECT
						b.bettype,
						b.transid,
						ISNULL(b.betid, 0) AS BetID,
						b.refno,
						'' AS matchcode,
						'' AS race,
						'' AS eventdate,
						0 AS virtualrate,
						0 AS isShowOTExRate,
						AVG(brng.sdiscount) AS sdiscount,
						AVG(brng.adiscount) AS adiscount,
						AVG(brng.discount) AS discount,
						AVG(brng.playerdiscount) AS playerdiscount,
						0 AS homeid,
						0 AS awayid,
						'' AS settleTime,
						0 AS hdp1,
						0 AS hdp2,
						CASE
							WHEN s.ProductID IN (6, 32, 36, 42, 66)
								THEN ISNULL(AVG(CASE WHEN brng.statusID IN (111, 112, 113) THEN brng.ContributionRate END), 0)
							ELSE 0
						END AS Odds,
						0 finalodds,
						0 finalodds2,
						0 AS OddsType,
						CASE 
							WHEN SUM(brng.winlost - brng.actual_stake) > 0 THEN 'Won'
							WHEN SUM(brng.winlost - brng.actual_stake) < 0 THEN 'Lose'
							ELSE 'Draw'
						END AS Status,
						0 AS SettlementStatus,
						CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
						SUM(brng.stake) AS stake,
						SUM(brng.actual_stake) AS actual_stake,
						b.transdate,
						'' AS betteam,
						AVG(brng.spositiontaking) AS spositiontaking,
						AVG(brng.mpositiontaking) AS mpositiontaking,
						AVG(brng.apositiontaking) AS apositiontaking,
						0 AS spositiontaking2,
						0 AS mpositiontaking2,
						0 AS apositiontaking2,
						0 AS liveindicator,
						0 AS modds,
						b.custid,
						0 AS livehomescore,
						0 AS liveawayscore,
						0,
						0,
						0 AS leagueid,
						CASE
							WHEN s.ProductID = 22 THEN 212
							WHEN s.ProductID = 32 THEN 248
							ELSE b.matchid
						END AS Sporttype,
						b.ip,
						0 AS matchid,
						CONVERT(BIT, 0) AS IsNeutral,
						0 AS allowdelete,
						SUM(brng.winlost - brng.actual_stake) AS WinLost,
						SUM(brng.playercomm) AS commission,
						SUM(brng.scomm - brng.acomm) AS scomm,
						SUM(brng.acomm - brng.comm) AS acomm,
						SUM(brng.comm - brng.playercomm) AS comm,
						SUM(brng.awinlost) AS awinlost,
						SUM(brng.mwinlost) AS mwinlost,
						SUM(brng.swinlost) AS swinlost,
						'' AS showtime,
						b.winlostdate,
						'' AS BetCheck,
						CASE
							WHEN s.ProductID IN (6, 22, 32, 34, 36, 55, 56, 61, 62, 67, 68) THEN b.transdesc
							ELSE ''
						END AS transdesc,
						CASE
							WHEN s.ProductID IN (6, 32, 36, 42, 66) THEN ISNULL(SUM(brng.BetStake), 0)
							ELSE 0
						END AS OddsSpread,
						0 AS OriginalBetType,
						-1 AS BetdaqId,
						'' AS ExtraInfo,
						'' AS JackpotInfo,
						0 AS WalletType,
						0 AS RefCode,
						0 AS currencyId,
						'' AS SiteId
					FROM dbo.bettransRnG AS brng WITH (NOLOCK)
						INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON brng.RefNo = b.transid
						INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
					WHERE
						b.transid = @TransId
						AND (s.ProductId IN (22, 32, 34, 36, 42, 50, 55, 56, 60, 61, 62, 66, 67, 68, 72, 73, 75)
							OR (s.ProductId = 6 AND s.SubProduct <> ''))
						AND brng.statusid NOT IN (0, 1)
					GROUP BY
						b.transid,
						ISNULL(b.betid, 0),
						b.bettype,
						b.refno,
						b.transdate,
						b.winlostdate,
						b.custid,
						b.ip,
						b.Username,
						b.comstatus,
						b.matchid,
						b.transdesc,
						s.ProductID
				END
				ELSE
				BEGIN
					-- Before yesterday settled ticket
					INSERT INTO @Data
					SELECT
						b.bettype,
						b.transid,
						ISNULL(b.betid, 0) AS BetID,
						b.refno,
						'' AS matchcode,
						'' AS race,
						'' AS eventdate,
						0 AS virtualrate,
						0 AS isShowOTExRate,
						b.sdiscount,
						b.adiscount,
						b.discount,
						b.playerdiscount,
						0 AS homeid,
						0 AS awayid,
						'' AS settleTime,
						0 AS hdp1,
						0 AS hdp2,
						CASE
							WHEN s.ProductID IN (6, 32, 36, 42, 66) THEN b.odds
							ELSE 0
						END AS Odds,
						0 AS finalodds,
						0 AS finalodds2,
						0 AS OddsType,
						b.status,
						0 AS SettlementStatus,
						CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
						b.stake,
						b.actual_stake,
						b.transdate,
						'' AS betteam,
						b.spositiontaking,
						b.mpositiontaking,
						b.apositiontaking,
						0 AS spositiontaking2,
						0 AS mpositiontaking2,
						0 AS apositiontaking2,
						0 AS liveindicator,
						0 AS modds,
						b.custid,
						0 AS livehomescore,
						0 AS liveawayscore,
						0,
						0,
						0 AS leagueid,
						CASE
							WHEN s.ProductID = 22 THEN 212
							WHEN s.ProductID = 32 THEN 248
							ELSE b.matchid
						END AS Sporttype,
						b.ip,
						0 AS matchid,
						CONVERT(BIT, 0) AS IsNeutral,
						0 AS allowdelete,
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
						'' AS BetCheck,
						CASE
							WHEN s.ProductID IN (6, 22, 32, 34, 36, 55, 56, 61, 62, 67, 68) THEN b.transdesc
							ELSE ''
						END AS transdesc,
						CASE
							WHEN s.ProductID IN (6, 32, 36, 42, 66) THEN ISNULL(b.oddsspread, 0)
							ELSE 0
						END AS OddsSpread,
						0 AS OriginalBetType,
						-1 AS BetdaqId,
						'' AS ExtraInfo,
						'' AS JackpotInfo,
						0 AS WalletType,
						0 AS RefCode,
						b.currency,
						'' AS SiteId
					FROM dbo.bettrans AS b WITH (NOLOCK)
						INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
					WHERE b.transid = @TransId
						AND (s.ProductId IN (22, 32, 34, 36, 42, 50, 55, 56, 60, 61, 62, 66, 67, 68, 72, 73, 75)
							OR (s.ProductId = 6 AND s.SubProduct <> ''))
				END
			END

			-- AG Casino, AllBet, SA Gaming, Sexy Gaming, IBCBet Live Casino, ION, WM, Big Gaming, PP Live Casino, FGG, YeeBet
			IF EXISTS (SELECT TOP(1) 1 FROM @SportBettype WHERE ProductID IN (11, 21, 39, 45, 46, 51, 52, 57, 65, 70, 76) AND Bettype = @BetType)
			BEGIN
				IF @WinLostDate >= DATEADD(DAY, DATEDIFF(DAY, 1, GETDATE()), 0)	-- yesterday and later
				BEGIN
					-- Yesterday and later running ticket
					INSERT INTO @Data
					SELECT
						b.bettype,
						b.transid,
						ISNULL(b.betid, 0) AS BetID,
						b.refno,
						'' AS matchcode,
						'' AS race,
						'' AS eventdate,
						0 AS virtualrate,
						0 AS isShowOTExRate,
						AVG(blc.sdiscount) AS sdiscount,
						AVG(blc.adiscount) AS adiscount,
						AVG(blc.discount) AS discount,
						AVG(blc.playerdiscount) AS playerdiscount,
						0 AS homeid,
						0 AS awayid,
						'' AS settleTime,
						0 AS hdp1,
						0 AS hdp2,
						0 AS odds,
						0 AS finalodds,
						0 AS finalodds2,
						0 AS OddsType,
						'Running' AS Status,
						0 AS SettlementStatus,
						CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
						SUM(blc.stake) AS stake,
						SUM(blc.actual_stake) AS actual_stake,
						b.transdate,
						'' AS betteam,
						AVG(blc.spositiontaking) AS spositiontaking,
						AVG(blc.mpositiontaking) AS mpositiontaking,
						AVG(blc.apositiontaking) AS apositiontaking,
						0 AS spositiontaking2,
						0 AS mpositiontaking2,
						0 AS apositiontaking2,
						0 AS liveindicator,
						0 AS modds,
						b.custid,
						0 AS livehomescore,
						0 AS liveawayscore,
						0,
						0,
						0 AS leagueid,
						CASE
							WHEN s.ProductID = 11 THEN 250
							WHEN s.ProductID = 21 THEN 211
							ELSE b.matchid
						END AS Sporttype,
						b.ip,
						0 AS matchid,
						CONVERT(BIT, 0) AS IsNeutral,
						0 AS allowdelete,
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
						'' AS BetCheck,
						'' AS transdesc,
						0 AS OddsSpread,
						0 AS OriginalBetType,
						-1 AS BetdaqId,
						'' AS ExtraInfo,
						'' AS JackpotInfo,
						0 AS WalletType,
						0 AS RefCode,
						0 AS CurrencyId,
						'' AS SiteId
					FROM dbo.bettransLC AS blc WITH (NOLOCK)
						INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON blc.RefNo = b.transid
						INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
					WHERE
						b.transid = @TransId
						AND s.ProductID IN (11, 21, 39, 45, 46, 51, 52, 57, 65, 70, 76)
						AND blc.statusID IN (0, 1)
					GROUP BY
						b.transid,
						ISNULL(b.betid, 0),
						b.Bettype,
						b.refno,
						b.transdate,
						b.winlostdate,
						b.custid,
						b.ip,
						b.Username,
						b.comstatus,
						s.ProductID,
						b.matchid

					-- Yesterday and today settled ticket
					INSERT INTO @Data
					SELECT
						b.bettype,
						b.transid,
						ISNULL(b.betid, 0) AS BetID,
						b.refno,
						'' AS matchcode,
						'' AS race,
						'' AS eventdate,
						0 AS virtualrate,
						0 AS isShowOTExRate,
						AVG(blc.sdiscount) AS sdiscount,
						AVG(blc.adiscount) AS adiscount,
						AVG(blc.discount) AS discount,
						AVG(blc.playerdiscount) AS playerdiscount,
						0 AS homeid,
						0 AS awayid,
						'' AS settleTime,
						0 AS hdp1,
						0 AS hdp2,
						0 AS odds,
						0 finalodds,
						0 finalodds2,
						0 AS OddsType,
						CASE 
							WHEN SUM(blc.winlost - blc.actual_stake) > 0 THEN 'Won'
							WHEN SUM(blc.winlost - blc.actual_stake) < 0 THEN 'Lose'
							ELSE 'Draw'
						END AS Status,
						0 AS SettlementStatus,
						CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
						SUM(blc.stake) AS stake,
						SUM(blc.actual_stake) AS actual_stake,
						b.transdate,
						'' AS betteam,
						AVG(blc.spositiontaking) AS spositiontaking,
						AVG(blc.mpositiontaking) AS mpositiontaking,
						AVG(blc.apositiontaking) AS apositiontaking,
						0 AS spositiontaking2,
						0 AS mpositiontaking2,
						0 AS apositiontaking2,
						0 AS liveindicator,
						0 AS modds,
						b.custid,
						0 AS livehomescore,
						0 AS liveawayscore,
						0,
						0,
						0 AS leagueid,
						CASE
							WHEN s.ProductID = 11 THEN 250
							WHEN s.ProductID = 21 THEN 211
							ELSE b.matchid
						END AS Sporttype,
						b.ip,
						0 AS matchid,
						CONVERT(BIT, 0) AS IsNeutral,
						0 AS allowdelete,
						SUM(blc.winlost - blc.actual_stake) AS WinLost,
						SUM(blc.playercomm) AS commission,
						SUM(blc.scomm - blc.acomm) AS scomm,
						SUM(blc.acomm - blc.comm) AS acomm,
						SUM(blc.comm - blc.playercomm) AS comm,
						SUM(blc.awinlost) AS awinlost,
						SUM(blc.mwinlost) AS mwinlost,
						SUM(blc.swinlost) AS swinlost,
						'' AS showtime,
						b.winlostdate,
						'' AS BetCheck,
						'' AS transdesc,
						0 AS OddsSpread,
						0 AS OriginalBetType,
						-1 AS BetdaqId,
						'' AS ExtraInfo,
						'' AS JackpotInfo,
						0 AS WalletType,
						0 AS RefCode,
						0 AS CurrencyId,
						'' AS SiteId
					FROM dbo.bettransLC AS blc WITH (NOLOCK)
						INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON blc.RefNo = b.transid
						INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
					WHERE
						b.transid = @TransId
						AND s.ProductID IN (11, 21, 39, 45, 46, 51, 52, 57, 65, 70, 76)
						AND blc.statusID NOT IN (0, 1)
					GROUP BY
						b.transid,
						ISNULL(b.betid, 0),
						b.Bettype,
						b.refno,
						b.transdate,
						b.winlostdate,
						b.custid,
						b.ip,
						b.Username,
						b.comstatus,
						s.ProductID,
						b.matchid
				END
				ELSE
				BEGIN
					-- Before yesterday settled ticket
					INSERT INTO @Data
					SELECT
						b.bettype,
						b.transid,
						ISNULL(b.betid, 0) AS BetID,
						b.refno,
						'' AS matchcode,
						'' AS race,
						'' AS eventdate,
						0 AS virtualrate,
						0 AS isShowOTExRate,
						b.sdiscount,
						b.adiscount,
						b.discount,
						b.playerdiscount,
						0 AS homeid,
						0 AS awayid,
						'' AS settleTime,
						0 AS hdp1,
						0 AS hdp2,
						0 AS odds,
						0 AS finalodds,
						0 AS finalodds2,
						0 AS OddsType,
						b.status,
						0 AS SettlementStatus,
						CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
						b.stake,
						b.actual_stake,
						b.transdate,
						'' AS betteam,
						b.spositiontaking,
						b.mpositiontaking,
						b.apositiontaking,
						0 AS spositiontaking2,
						0 AS mpositiontaking2,
						0 AS apositiontaking2,
						0 AS liveindicator,
						0 AS modds,
						b.custid,
						0 AS livehomescore,
						0 AS liveawayscore,
						0,
						0,
						0 AS leagueid,
						CASE
							WHEN s.ProductID = 11 THEN 250
							WHEN s.ProductID = 21 THEN 211
							ELSE b.matchid
						END AS Sporttype,
						b.ip,
						0 AS matchid,
						CONVERT(BIT, 0) AS IsNeutral,
						0 AS allowdelete,
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
						'' AS BetCheck,
						'' AS transdesc,
						0 AS OddsSpread,
						0 AS OriginalBetType,
						-1 AS BetdaqId,
						'' AS JackpotInfo,
						'' AS ExtraInfo,
						0 AS WalletType,
						0 AS RefCode,
						b.currency,
						'' AS SiteId
					FROM dbo.bettrans AS b WITH (NOLOCK)
						INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
					WHERE b.transid = @TransId
						AND s.ProductID IN (11, 21, 39, 45, 46, 51, 52, 57, 65, 70, 76)
				END
			END

			-- Get related Bonus/Cash tickets
			IF EXISTS ( SELECT 1 FROM @Data WHERE RefCode <> 0 )
			BEGIN
				INSERT INTO @Data
				SELECT
					b.bettype,
					b.transid,
					ISNULL(b.BetID,0) AS BetID,
					b.refno,
					m.matchcode,
					'' AS race,
					m.GlobalShowTime AS EventDate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					b.playerdiscount,
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
					ISNULL(m.SettlementStatus, 0) AS SettlementStatus,
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
					b.matchid,
					ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
					CASE 
						WHEN b.bettype IN (SELECT typeid FROM @tableBettypeNotAllowDelete) OR statusID NOT IN (0, 1, 112, 113, 111) THEN 0 
						ELSE 1 
					END AS allowdelete,
					(b.winlost-b.actual_stake) AS winlost,
					b.playercomm AS commission,
					(b.scomm - b.acomm) AS scomm,
					(b.acomm - b.comm) AS acomm,
					(b.comm - b.playercomm) AS comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					m.showtime,
					b.winlostdate,
					b.BetCheck,
					ISNULL(b.transdesc, '') AS transdesc,
					ISNULL(b.oddsspread, 0) AS OddsSpread,	-- For Myanmar Odds
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					ISNULL(b.ExtraInfo, '') AS ExtraInfo,
					'' AS JackpotInfo,
					ISNULL(b.WalletType, 0) AS WalletType,
					ISNULL(b.RefCode, 0) AS RefCode,
					b.currency,
					'' AS SiteId
				FROM
					dbo.bettrans AS b WITH (NOLOCK)
					INNER JOIN @Data AS b1
						ON b.custid = b1.CustId
						AND b.winlostdate = b1.WinLostDate
						AND b.RefCode = b1.RefCode
						AND b.transid <> b1.transid
					INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
			END
		END
	END

	-- Get original odds for Mix Parlay and final odds, boost rate for Mix Parlay Boost Bonus
	IF EXISTS (SELECT 1 FROM @Data WHERE BetType = 29 AND BetTeam = '1')
	BEGIN
		-- Running/Waiting
		DECLARE @ParlayData TABLE (
			RefNo		BIGINT,
			BoostRate	MONEY)

		INSERT INTO @ParlayData
		SELECT
			b.refno,
			CASE
				WHEN b.bettype = 29 AND b.betteam = 1 AND b.oddsspread = 2 THEN
					ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p1/@bbp)[1]','MONEY'), 0)
				ELSE 0
			END AS BoostRate
		FROM @Data AS b
		WHERE b.BetType = 29
			AND b.BetTeam = '1'
			AND b.Status IN ('Running', 'Waiting')

		DECLARE @TmpParlayData TABLE (
			RefNo	BIGINT,
			Odds	MONEY,
			MOdds	MONEY)

		-- Mix Parlay which having at least 1 settled sub ticket
		INSERT INTO @TmpParlayData
		SELECT
			b.RefNo,
			dbo.PRODUCT(bpd.odds) AS Odds,
			dbo.PRODUCT(bpd.odds) * (b.BoostRate + 1) - b.BoostRate AS MOdds
		FROM @ParlayData AS b
			INNER JOIN dbo.BetParlayDetail AS bpd WITH (NOLOCK) ON bpd.RefNo = b.RefNo
		GROUP BY
			b.RefNo,
			b.BoostRate

		-- Mix Parlay which having no settled sub ticket
		INSERT INTO @TmpParlayData
		SELECT
			b.RefNo,
			dbo.PRODUCT(bm.odds) AS Odds,
			dbo.PRODUCT(bm.odds) * (b.BoostRate + 1) - b.BoostRate AS MOdds
		FROM @ParlayData AS b
			INNER JOIN dbo.bettransm AS bm WITH (NOLOCK) ON bm.refno = b.RefNo
		WHERE NOT EXISTS (SELECT 1 FROM @TmpParlayData WHERE RefNo = b.RefNo)
		GROUP BY
			b.RefNo,
			b.BoostRate

		UPDATE b
		SET
			b.Odds = td.Odds,
			b.MOdds = td.MOdds
		FROM @Data AS b
			INNER JOIN @TmpParlayData AS td ON td.RefNo = b.RefNo

		-- Settled
		UPDATE b
		SET
			b.Odds = bpr.Odds,
			b.Modds = bpr.mOdds,
			b.TransDesc = CONVERT(VARCHAR(20), ISNULL(bpr.ExtraValue, ''))
		FROM @Data AS b
			INNER JOIN dbo.BetParlayResult AS bpr WITH (NOLOCK) ON bpr.RefNo = b.RefNo
		WHERE b.BetType = 29
			AND b.BetTeam = '1'
			AND b.Status NOT IN ('Running', 'Waiting')
	END
	
	-- Don't display Cash text for ticket from Cash Wallet only
	UPDATE @Data
	SET WalletType = 0
	WHERE WalletType = 2 AND RefCode = 0

	-- Display Cash/Bonus text for ticket from multiple wallets
	UPDATE @Data
	SET RefCode = 0
	WHERE RefCode <> 0

	DECLARE @DetailData TABLE (
		RefNo			NVARCHAR(50),
		Odds			MONEY,
		Stake			MONEY,
		Status			NVARCHAR(50),
		APositionTaking	SMALLMONEY,
		MPositionTaking	SMALLMONEY,
		SPositionTaking	SMALLMONEY,
		BetType			SMALLINT,
		BetTeam			NVARCHAR(50),
		TransDesc		VARCHAR(2000)
	)

	-- Virtual Sports
	IF EXISTS (	SELECT TOP(1) 1
				FROM @SportBettype AS sp
					INNER JOIN @Data AS d ON d.bettype = sp.bettype
				WHERE sp.ProductID = 5 AND sp.EventType = 3)
	BEGIN
		IF @WinLostDate > @MoveBetsDay
		BEGIN
			INSERT INTO @DetailData
			SELECT
				bm.refno,
				bm.odds,
				bm.stake,
				bm.status,
				bm.apositiontaking,
				bm.mpositiontaking,
				bm.spositiontaking,
				bm.bettype,
				bm.betteam,
				'' AS TransDesc
			FROM dbo.bettransm AS bm WITH (NOLOCK)
				INNER JOIN @SportBettype AS sp ON bm.bettype = sp.bettype
				INNER JOIN @Data AS b ON bm.custid = b.CustId AND bm.refno = b.RefNo
			WHERE sp.ProductID = 5 AND sp.EventType = 3
		END
	END

	-- BettransRnG tables
	SET @WinLostDate = NULL

	-- bettransRnG
	SELECT TOP(1)
		@TransId = b.transid,
		@WinLostDate = b.winlostdate,
		@BetType = b.gameID
	FROM dbo.bettransRnG AS b WITH (NOLOCK)
		INNER JOIN @SportBettype AS sp ON b.gameID = sp.Bettype
	WHERE b.custid = @CustId AND b.transid = @RefNo

	IF @WinLostDate IS NOT NULL
	BEGIN
		-- bettransRnG
		IF @WinLostDate > @MoveBetsDay
		BEGIN
			-- RNG Casino Single Wallet, Macau Games, Pragmatic Casino, Card Club, Spadegaming, Saba.club, RNG War, PG Soft, Joker, MaxGame, Habanero, CG, VGaming
			-- AdvantPlay, AdvantPlay Mini, SEAL, MG RNGCasino, Jili
			IF EXISTS (	SELECT TOP(1) 1 FROM @SportBettype 
						WHERE Bettype = @BetType
							AND (ProductID IN (22, 32, 34, 36, 42, 50, 55, 56, 60, 61, 62, 66, 67, 68, 72, 73, 75)
								OR (ProductID = 6 AND SubProduct <> '')))
			BEGIN
				INSERT INTO @Data
				SELECT
					b.gameID AS BetType,
					b.transid,
					0 AS BetID,
					b.refno,
					CASE
						WHEN s.productID IN (42) THEN ISNULL(b.SiteID, '')
						ELSE b.Additional
					END AS MatchCode,
					'' AS race,
					CASE
						WHEN s.productID IN (60) THEN b.Transdate3rd
						ELSE ''
					END AS EventDate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					b.playerdiscount,
					0 AS homeid,
					0 AS awayid,
					'' AS settleTime,
					0 AS hdp1,
					0 AS hdp2,
					CASE
						WHEN s.ProductID IN (6, 32, 36, 42, 66) AND b.statusID IN (111, 112, 113) THEN ISNULL(b.ContributionRate, 0)
						ELSE b.odds
					END AS Odds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS OddsType,
					b.status,
					0 AS SettlementStatus,
					'' AS comstatus,
					b.stake,
					b.actual_stake,
					b.transdate,
					CASE
						WHEN s.productID IN (6, 22, 32, 34, 36, 50, 55, 56, 60, 61, 62, 67, 68, 73) THEN b.GameId3rd
					ELSE ''
					END AS BetTeam,
					b.spositiontaking,
					b.mpositiontaking,
					b.apositiontaking,
					0 AS spositiontaking2,
					0 AS mpositiontaking2,
					0 AS apositiontaking2,
					0 AS liveindicator,
					0 AS modds,
					b.custid,
					0 AS livehomescore,
					0 AS liveawayscore,
					0 AS finalhomescore,
					0 AS finalawayscore,
					0 AS leagueid,
					b.productID AS Sporttype,
					b.ip,
					0 AS matchid,
					CONVERT(BIT, 0) AS IsNeutral,
					0 AS allowdelete,
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
					b.TranId3rd AS BetCheck,
					b.transdesc,
					CASE
						WHEN s.ProductID IN (6, 32, 36, 42, 66) AND b.statusID IN (111, 112, 113) THEN ISNULL(b.BetStake, 0)
						ELSE 0
					END AS OddsSpread,
					0 AS OriginalBetType,
					CASE
						WHEN s.ProductID IN (6, 32, 36, 42, 66) THEN ISNULL(b.RefNo2, -1)
						ELSE -1
					END AS BetdaqId,
					b.ExtraInfo,
					CASE
						WHEN s.ProductID IN (6, 32, 36, 42, 66) THEN ISNULL(b.JackpotInfo, '')
						ELSE ''
					END AS JackpotInfo,
					0 AS WalletType,
					0 AS RefCode,
					b.currency,
					b.SiteId
				FROM dbo.bettransRnG AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = b.gameID
				WHERE b.transid = @TransId
					AND (s.ProductId IN (22, 32, 34, 36, 42, 50, 55, 56, 60, 61, 62, 66, 67, 68, 72, 73, 75)
						OR (s.ProductId = 6 AND s.SubProduct <> ''))
			END
		END
	END

	-- BettransLC tables
	SET @WinLostDate = NULL

	-- bettransLC
	SELECT TOP(1)
		@TransId = b.transid,
		@WinLostDate = b.winlostdate,
		@BetType = b.gameID
	FROM dbo.bettransLC AS b WITH (NOLOCK)
		INNER JOIN @SportBettype AS sp ON b.gameID = sp.bettype
	WHERE b.custid = @CustId AND b.transid = @RefNo

	IF @WinLostDate IS NOT NULL
	BEGIN
		-- bettransLC
		IF @WinLostDate > @MoveBetsDay
		BEGIN
			-- AG Casino, AllBet, Sexy Gaming, IBCBet Live Casino, ION, WM, Big Gaming, PP Live Casino, FGG, YeeBet
			IF EXISTS (SELECT TOP(1) 1 FROM @SportBettype WHERE ProductID IN (11, 21, 45, 46, 52, 51, 57, 65, 70, 76) AND Bettype = @BetType)
			BEGIN
				INSERT INTO @Data
				SELECT
					b.gameID AS BetType,
					b.transid,
					0 AS BetID,
					b.refno,
					CASE
						WHEN s.ProductID IN (21, 45, 46, 51, 52, 57, 65, 70, 76) THEN b.GameId3rd
						ELSE ''
					END AS matchcode,
					'' AS race,
					CASE
						WHEN s.ProductID IN (70) THEN b.TransDate3rd
						ELSE '' 
					END AS eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					b.playerdiscount,
					0 AS homeid,
					0 AS awayid,
					'' AS settleTime,
					0 AS hdp1,
					0 AS hdp2,
					CASE
						WHEN s.ProductID IN (21, 45, 46, 51, 52, 57) THEN b.odds
						ELSE 0
					END AS odds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS OddsType,
					b.status,
					0 AS SettlementStatus,
					'' AS comstatus,
					b.stake,
					b.actual_stake,
					b.transdate,
					'' AS betteam,
					b.spositiontaking,
					b.mpositiontaking,
					b.apositiontaking,
					0 AS spositiontaking2,
					0 AS mpositiontaking2,
					0 AS apositiontaking2,
					0 AS liveindicator,
					0 AS modds,
					b.custid,
					0 AS livehomescore,
					0 AS liveawayscore,
					0 AS finalhomescore,
					0 AS finalawayscore,
					0 AS leagueid,
					b.productID AS Sporttype,
					b.ip,
					0 AS matchid,
					CONVERT(BIT, 0) AS IsNeutral,
					0 AS allowdelete,
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
					b.TranId3rd AS BetCheck,
					b.transdesc,
					0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					b.ExtraInfo,
					'' AS JackpotInfo,
					0 AS WalletType,
					0 AS RefCode,
					b.currency,
					b.SiteId
				FROM dbo.bettransLC AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = b.gameID
				WHERE b.transid = @TransId
					AND s.ProductID IN (11, 21, 45, 46, 51, 52, 57, 65, 70, 76)
			END
		END
	END

	-- Bettransg tables
	SET @WinLostDate = NULL

	-- bettransg
	SELECT TOP(1)
		@TransId = b.transid,
		@WinLostDate = b.winlostdate,
		@BetType = b.bettype
	FROM dbo.bettransg AS b WITH (NOLOCK)
		INNER JOIN @SportBettype AS sp ON b.bettype = sp.bettype
	WHERE b.custid = @CustId AND b.transid = @RefNo

	IF @WinLostDate IS NOT NULL
	BEGIN
		-- bettransg
		IF @WinLostDate > @MoveBetsDay
		BEGIN
			-- SA Gaming
			IF EXISTS (SELECT TOP(1) 1 FROM @SportBettype WHERE ProductID IN (39) AND Bettype = @BetType)
			BEGIN
				INSERT INTO @Data
				SELECT
					b.bettype,
					b.transid,
					0 AS BetID,
					b.refno,
					ISNULL(blc.GameId3rd, '') AS matchcode,
					'' AS race,
					'' AS eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					b.playerdiscount,
					0 AS homeid,
					0 AS awayid,
					'' AS settleTime,
					0 AS hdp1,
					0 AS hdp2,
					b.odds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS OddsType,
					b.status,
					0 AS SettlementStatus,
					'' AS comstatus,
					b.stake,
					b.actual_stake,
					b.transdate,
					ISNULL(b.BetID3rd, '') AS BetTeam,
					b.spositiontaking,
					b.mpositiontaking,
					b.apositiontaking,
					0 AS spositiontaking2,
					0 AS mpositiontaking2,
					0 AS apositiontaking2,
					0 AS liveindicator,
					0 AS modds,
					b.custid,
					0 AS livehomescore,
					0 AS liveawayscore,
					0 AS finalhomescore,
					0 AS finalawayscore,
					0 AS leagueid,
					ISNULL(blc.ProductID, 0) AS Sporttype,
					ISNULL(blc.ip, '') AS Ip,
					0 AS matchid,
					CONVERT(BIT, 0) AS IsNeutral,
					0 AS allowdelete,
					b.winlost - b.actual_stake AS WinLost,
					b.playercomm AS Commission,
					b.scomm - b.acomm AS SComm,
					b.acomm - b.comm AS AComm,
					b.comm - b.playercomm AS Comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					'' AS showtime,
					b.winlostdate,
					ISNULL(b.TransDesc, '') AS BetCheck,
					ISNULL(blc.transdesc, '') AS TransDesc,
					0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					b.ExtraInfo,
					'' AS JackpotInfo,
					0 AS WalletType,
					0 AS RefCode,
					b2.currency,
					b.SiteId
				FROM dbo.bettransg AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = b.Bettype
					INNER JOIN dbo.bettransLC AS blc WITH (NOLOCK) ON b.refno = blc.transid AND b.custid = blc.CustId
					INNER JOIN dbo.bettrans AS b2 WITH (NOLOCK) ON b2.transid = blc.refno AND b2.custid = b.CustId
				WHERE b.transid = @TransId AND s.ProductID IN (39)
			END

			-- BBIN
			IF EXISTS (SELECT TOP(1) 1 FROM @SportBettype WHERE ProductID IN (47) AND Bettype = @BetType)
			BEGIN
				INSERT INTO @Data
				SELECT
					b.bettype,
					b.transid,
					0 AS BetID,
					b.refno,
					'' AS matchcode,
					'' AS race,
					'' AS eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					b.playerdiscount,
					0 AS homeid,
					0 AS awayid,
					'' AS settleTime,
					0 AS hdp1,
					0 AS hdp2,
					b.odds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS OddsType,
					b.status,
					0 AS SettlementStatus,
					'' AS comstatus,
					b.stake,
					b.actual_stake,
					b.transdate,
					ISNULL(b.betteam, '') AS BetTeam,
					b.spositiontaking,
					b.mpositiontaking,
					b.apositiontaking,
					0 AS spositiontaking2,
					0 AS mpositiontaking2,
					0 AS apositiontaking2,
					0 AS liveindicator,
					0 AS modds,
					b.custid,
					0 AS livehomescore,
					0 AS liveawayscore,
					0 AS finalhomescore,
					0 AS finalawayscore,
					0 AS leagueid,
					b.matchid AS Sporttype,
					ISNULL(b2.ip, '') AS Ip,
					0 AS matchid,
					CONVERT(BIT, 0) AS IsNeutral,
					0 AS allowdelete,
					b.winlost - b.actual_stake AS WinLost,
					b.playercomm AS Commission,
					b.scomm - b.acomm AS SComm,
					b.acomm - b.comm AS AComm,
					b.comm - b.playercomm AS Comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					'' AS showtime,
					b.winlostdate,
					ISNULL(b.BetID3rd, '') AS BetCheck,
					ISNULL(b.transdesc, '') AS TransDesc,
					0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					'' AS ExtraInfo,
					'' AS JackpotInfo,
					0 AS WalletType,
					0 AS RefCode,
					b2.currency,
					b.SiteId
				FROM dbo.bettransg AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = b.Bettype
					INNER JOIN dbo.bettrans AS b2 WITH (NOLOCK) ON b2.transid = b.refno AND b2.custid = b.CustId
				WHERE b.transid = @TransId AND s.ProductID IN (47)
			END
		END
	END

	SELECT b.*,
		@CustId AS CustId,
		ex.currency,
		c.ugroup,
		c.username
	FROM @Data AS b
		LEFT JOIN CustDB.dbo.Customer AS c WITH (NOLOCK) ON b.CustId = c.custid
		LEFT JOIN CustDB.dbo.Exchange AS ex WITH (NOLOCK) ON c.currency = ex.exchangeid
	ORDER BY b.TransId ASC

	SELECT * FROM @DetailData
END
GO