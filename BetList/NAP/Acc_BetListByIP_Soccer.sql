/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Acc_BetListByIP_Soccer]
	@CustId			INT,
	@Ip				VARCHAR(15),
	@FromDate		SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@BalanceUpDay	SMALLDATETIME
AS
/*
	Created: Phuong Dao
	Task: Bet List By IP and Soccer
	DB: DBACC.bodb02 
	Original: Acc_BetListByDayAllIP

	Revisions:
		- 20090514@Simon: Remove RefNo
		- 20091002@Simon: Get Odds && OddsType columns
		- 20091003@Jamie: Remove comstatus out
		- 20091009@Daniel: Get refund status from bettrans
		- 20091205@Henry: Get more column: refno for viewing Mix Parlay detail
		- 20101205@Daniel: Fix swap column transid & refno due to diff column order between select statements
		- 20100611@Henry: Change mix-parlay match from 0 to 9
		- 20101201@Henry: Return winlost-actual_stake for column winlost
		- 20110408@Amy: Change function to get Odds value and odds type
		- 20110516@Lukas: re-arrange bettype
		- 20110802@Johnson: Add column actual_stake into betlist
						- Add new bettype combination mix-parlay
		- 20111122@Sophia: Add Checktime and SecAcceptFlag to show status waiting or running
		- 20120120@Sophia: Add Showtime for Table-hand-shoe of Live Casino
						- Add sub detail for Live Casino
		- 20120426@Lukas: Show transid of mainticket for sub-tickets of system parlay
		- 20120606@Sophia: Change datatype of stake to money
		- 20120626@Elodie: exclude outright from sportbook ( in case of matchid = orid)
		- 20120629@Sophia: Remove function f_GetOddsByBettype, f_ShowOddsByBettype,f_GetChoice for odds, Oddstype, betteam
		- 20120927@Johnson: get commstatus column to check double comm losing
		- 20130718@Elodie: Apply core betlist
		- 20150415@Sophia: Get Betcheck for Betradar
		- 20150506@Bobby: Add transdesc column for metric gaming bettypes (801-899)
		- 20150615@Edward: Support for BetTrade
		- 20150707@Bobby: Exclude Metric Gaming running ticket from bettrans table
		- 20150826@Kos: Add OddsSpread column to support Myanmar Odds
		- 20151210@Kos: Change odds, modds data type from SMALLMONEY to MONEY [Redmine: #48660]
		- 20160119@Kos: Support PH All In One 1.2 [#Redmine: 50897]
		- 20160407@Kos: Support Combo Parlay [#Redmine: 55282]
		- 20160804@Kos: Exclude bet type 904 [#Redmine: 58978]
		- 20170321@Kos: Support CashOut [#Redmine: 71963]
		- 20170602@Kos: Get liveindicator from original ticket for 911 and 912 tickets [#Redmine: 77669]
		- 20170615@Kos: Support Licensee Bonus System [#Redmine: 74978]
		- 20180328@Kos: Increase Transdesc length to 1000 [Redmine: #92841]
		- 20180927@Kos: Support new status Result Pending and Under Settlement [#Redmine: 101949]
		- 20190107@Kos: Support Parlay Changes [#Redmine: 105585]
		- 20190503@Kos: Show match KO time for single ticket [#Redmine: 112092]
		- 20190722@Kos: Support new status Pending [#Redmine: 113142]
		- 20190827@Kos: Support bk range [Redmine: #119018]
					- Don't support Microgaming Live Casino, Microgaming RNG Casino, Lucky 3, Poker Games anymore [Redmine: #119018]
					- Add new params @MoveBetsDay and @BalanceUpDay
		- 20191029@Kos: Show Running status for Marked tickets [Redmine: 122391]
		- 20200422@Kos: Support status Delay Payout [Redmine: #132629]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @Data TABLE (
		TransId				BIGINT,
		RefNo				BIGINT,
		CustId				INT,
		Creator				INT,
		Currency			SMALLINT,
		SportType			SMALLINT,
		BetType				SMALLINT,
		BetId				BIGINT,
		BetTeam				NVARCHAR(20),
		Hdp1				SMALLMONEY,
		Hdp2				SMALLMONEY,
		OddsId				INT,
		OddsType			TINYINT,
		Odds				MONEY,
		MOdds				MONEY,
		OddsSpread			MONEY,
		Stake				MONEY,
		Actual_Stake		MONEY,
		WinLost				MONEY,
		Commission			MONEY,
		Status				NVARCHAR(10),
		SettlementStatus	TINYINT,
		SecAcceptFlag		BIT,
		CheckTime			DATETIME,
		TransDate			DATETIME,
		WinLostDate			SMALLDATETIME,
		LiveIndicator		BIT,
		LiveHomeScore		SMALLINT,
		LiveAwayScore		SMALLINT,
		Ip					NVARCHAR(15),
		BetFrom				NVARCHAR(1),
		LeagueId			INT,
		MatchId				INT,
		MatchCode			NVARCHAR(50),
		Race				NVARCHAR(50),
		EventDate			DATETIME,
		HomeId				INT,
		AwayId				INT,
		IsNeutral			BIT,
		ShowTime			NVARCHAR(50),
		BetCheck			NVARCHAR(50),
		ComStatus			NVARCHAR(20),
		TransDesc			NVARCHAR(1000),
		BetdaqId			BIGINT,
		ExtraInfo			VARCHAR(1000),
		OriginalBetType		SMALLINT,
		WalletType			TINYINT,
		RefCode				BIGINT,
		EventId				INT,
		Custom1				NVARCHAR(50),
		TableID				TINYINT,
		Product				VARCHAR(30)
	)

	-- Get ticket detail
	DECLARE @DetailData TABLE (
		RefNo			NVARCHAR(50),
		Odds			MONEY,
		Stake			MONEY,
		Status			NVARCHAR(50),
		APositionTaking SMALLMONEY,
		MPositionTaking SMALLMONEY,
		SPositionTaking SMALLMONEY,
		BetType			SMALLINT,
		BetTeam			NVARCHAR(50),
		TransDesc		VARCHAR(300)
	)

	DECLARE @Date DATETIME

	SET @Date = @FromDate

	-- bettrans range
	IF @Date > @MoveBetsDay
	BEGIN
		-- bettrans
		INSERT INTO @Data (
			TransId,
			RefNo,
			CustId,
			Creator,
			Currency,
			BetType,
			BetId,
			BetTeam,
			Hdp1,
			Hdp2,
			OddsId,
			OddsType,
			Odds,
			MOdds,
			OddsSpread,
			Stake,
			Actual_Stake,
			WinLost,
			Commission,
			Status,
			SecAcceptFlag,
			CheckTime,
			TransDate,
			WinLostDate,
			LiveIndicator,
			LiveHomeScore,
			LiveAwayScore,
			Ip,
			BetFrom,
			MatchId,
			BetCheck,
			ComStatus,
			TransDesc,
			BetdaqId,
			ExtraInfo,
			WalletType,
			RefCode,
			TableID)
		SELECT
			b.transid,
			b.refno,
			b.custid,
			b.creator,
			b.currency,
			b.bettype,
			ISNULL(b.betid, 0) AS BetId,
			b.betteam,
			b.hdp1,
			b.hdp2,
			b.oddsid,
			b.oddstype,
			b.odds,
			b.modds,
			b.oddsspread,
			b.stake,
			b.actual_stake,
			b.winlost,
			b.playercomm,
			b.status,
			b.SecAcceptFlag,
			b.checktime,
			b.transdate,
			b.winlostdate,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			b.ip,
			b.betfrom,
			b.matchid,
			b.betcheck,
			b.comstatus,
			b.transdesc,
			b.betdaqid,
			b.ExtraInfo,
			b.WalletType,
			ISNULL(b.RefCode, 0),
			1 AS TableID
		FROM dbo.bettrans AS b WITH (NOLOCK)
		WHERE b.custid = @CustId
			AND b.winlostdate = @Date
			AND b.ip = @Ip

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
				b.Stake = cob.stake
			FROM @Data AS b
				INNER JOIN dbo.bettrans AS cob WITH (NOLOCK) ON b.RefNo = cob.transid
				INNER JOIN dbo.bettrans AS ob WITH (NOLOCK) ON cob.RefNo = ob.transid
				LEFT JOIN @Data AS cb
					ON cb.RefNo = b.RefNo
					AND cb.BetType = 913
					AND cb.custid = @CustId
					AND cb.winlostdate = b.WinLostDate
			WHERE b.BetType = 912
		END

		-- translog
		INSERT INTO @Data (
			TransId,
			RefNo,
			CustId,
			Creator,
			Currency,
			BetType,
			Odds,
			Stake,
			Actual_Stake,
			Status,
			TransDate,
			WinLostDate,
			LiveIndicator,
			Ip,
			BetFrom,
			TransDesc,
			EventId,
			Custom1,
			TableID
		)
		SELECT
			b.translogid AS TransId,
			b.translogid AS RefNo,
			b.custid,
			b.creator,
			b.currency,
			b.gameID AS BetType,
			b.odds,
			b.stake,
			b.actual_stake,
			b.status,
			b.transdate,
			b.transdate AS WinLostDate,
			b.LiveIndicator,
			b.ip,
			b.betfrom,
			b.transdesc,
			b.eventID,
			b.custom1,
			4 AS TableID
		FROM dbo.translog AS b WITH (NOLOCK)
		WHERE b.custid = @CustId
			AND b.winlostdate = @Date
			AND b.ip = @Ip
			AND b.statusID IN (0, 1)
			AND b.gameID BETWEEN 801 AND 806
	END
	ELSE IF @Date BETWEEN @BalanceUpDay AND @MoveBetsDay		-- bettrans14 range
	BEGIN
		-- bettrans14
		INSERT INTO @Data (
			TransId,
			RefNo,
			CustId,
			Creator,
			Currency,
			BetType,
			BetId,
			BetTeam,
			Hdp1,
			Hdp2,
			OddsId,
			OddsType,
			Odds,
			MOdds,
			OddsSpread,
			Stake,
			Actual_Stake,
			WinLost,
			Commission,
			Status,
			SecAcceptFlag,
			CheckTime,
			TransDate,
			WinLostDate,
			LiveIndicator,
			LiveHomeScore,
			LiveAwayScore,
			Ip,
			BetFrom,
			MatchId,
			BetCheck,
			ComStatus,
			TransDesc,
			BetdaqId,
			ExtraInfo,
			WalletType,
			RefCode,
			TableID)
		SELECT
			b.transid,
			b.refno,
			b.custid,
			b.creator,
			b.currency,
			b.bettype,
			ISNULL(b.betid, 0) AS BetId,
			b.betteam,
			b.hdp1,
			b.hdp2,
			b.oddsid,
			b.oddstype,
			b.odds,
			b.modds,
			b.oddsspread,
			b.stake,
			b.actual_stake,
			b.winlost,
			b.playercomm,
			b.status,
			b.SecAcceptFlag,
			b.checktime,
			b.transdate,
			b.winlostdate,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			b.ip,
			b.betfrom,
			b.matchid,
			b.betcheck,
			b.comstatus,
			b.transdesc,
			b.betdaqid,
			b.ExtraInfo,
			b.WalletType,
			ISNULL(b.RefCode, 0),
			2 AS TableID
		FROM dbo.bettrans14 AS b WITH (NOLOCK)
		WHERE b.custid = @CustId
			AND b.winlostdate = @Date
			AND b.ip = @Ip

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
				INNER JOIN dbo.bettrans14 AS ob WITH (NOLOCK) ON b.RefNo = ob.transid
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
				b.Stake = cob.stake
			FROM @Data AS b
				INNER JOIN dbo.bettrans14 AS cob WITH (NOLOCK) ON b.RefNo = cob.transid
				INNER JOIN dbo.bettrans14 AS ob WITH (NOLOCK) ON cob.RefNo = ob.transid
				LEFT JOIN @Data AS cb
					ON cb.RefNo = b.RefNo
					AND cb.BetType = 913
					AND cb.custid = @CustId
					AND cb.winlostdate = b.WinLostDate
			WHERE b.BetType = 912
		END
	END
	ELSE IF @Date < @BalanceUpDay		-- bettrans_bk range
	BEGIN
		-- bettrans_bk
		INSERT INTO @Data (
			TransId,
			RefNo,
			CustId,
			Creator,
			Currency,
			BetType,
			BetId,
			BetTeam,
			Hdp1,
			Hdp2,
			OddsId,
			OddsType,
			Odds,
			MOdds,
			OddsSpread,
			Stake,
			Actual_Stake,
			WinLost,
			Commission,
			Status,
			SecAcceptFlag,
			CheckTime,
			TransDate,
			WinLostDate,
			LiveIndicator,
			LiveHomeScore,
			LiveAwayScore,
			Ip,
			BetFrom,
			MatchId,
			BetCheck,
			ComStatus,
			TransDesc,
			BetdaqId,
			ExtraInfo,
			WalletType,
			RefCode,
			TableID)
		SELECT
			b.transid,
			b.refno,
			b.custid,
			b.creator,
			b.currency,
			b.bettype,
			ISNULL(b.betid, 0) AS BetId,
			b.betteam,
			b.hdp1,
			b.hdp2,
			b.oddsid,
			b.oddstype,
			b.odds,
			b.modds,
			b.oddsspread,
			b.stake,
			b.actual_stake,
			b.winlost,
			b.playercomm,
			b.status,
			b.SecAcceptFlag,
			b.checktime,
			b.transdate,
			b.winlostdate,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			b.ip,
			b.betfrom,
			b.matchid,
			b.betcheck,
			b.comstatus,
			b.transdesc,
			b.betdaqid,
			b.ExtraInfo,
			b.WalletType,
			ISNULL(b.RefCode, 0),
			3 AS TableID
		FROM bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK, INDEX = IX_custid)
		WHERE b.custid = @CustId
			AND b.winlostdate = @Date
			AND b.ip = @Ip

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
				INNER JOIN bodb_Archive.dbo.bettrans_bk AS ob WITH (NOLOCK) ON b.RefNo = ob.transid
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
				b.Stake = cob.stake
			FROM @Data AS b
				INNER JOIN bodb_Archive.dbo.bettrans_bk AS cob WITH (NOLOCK) ON b.RefNo = cob.transid
				INNER JOIN bodb_Archive.dbo.bettrans_bk AS ob WITH (NOLOCK) ON cob.RefNo = ob.transid
				LEFT JOIN @Data AS cb
					ON cb.RefNo = b.RefNo
					AND cb.BetType = 913
					AND cb.custid = @CustId
					AND cb.winlostdate = b.WinLostDate
			WHERE b.BetType = 912
		END
	END

	IF EXISTS (SELECT 1 FROM @Data)
	BEGIN
		-- Get Sport Bettype Matrix
		DECLARE @SportBettype TABLE(ProductID TINYINT, Bettype SMALLINT, EventType TINYINT)

		DECLARE @IsTest BIT = 0

		SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

		INSERT INTO @SportBettype
		SELECT ProductID, BetType, EventType
		FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest)
		WHERE ProductID IN (1, 25)

		-- Get Sport/Bettype info
		UPDATE b
		SET
			Product = CASE
						WHEN s.EventType = 0 AND s.ProductID = 1 THEN 'Parlay'		-- Sportsbook Parlay
						WHEN s.EventType = 1 AND s.ProductID = 1 THEN 'SB'			-- Sportsbook
						WHEN s.EventType = 2 AND s.ProductID = 1 THEN 'Outright'
						WHEN s.ProductID = 25 THEN 'CO'								-- Cash Out
						ELSE 'Unknown'
					END
		FROM @Data AS b
			INNER JOIN @SportBettype AS s ON b.BetType = s.BetType

		DELETE @Data
		WHERE Product = 'Unknown'
			OR Product IS NULL
			OR BetType IN (903, 904, 913, 914)

		-- Delete Other Sports tickets
		IF @Date > @MoveBetsDay		-- bettrans range
		BEGIN
			-- Normal tickets
			DELETE b
			FROM @Data AS b
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.MatchId = m.matchid
			WHERE m.sporttype <> 1 AND b.Product = 'SB'

			-- Outright
			DELETE b
			FROM @Data AS b
				INNER JOIN dbo.outright AS o WITH (NOLOCK) ON o.orid = b.MatchId
				INNER JOIN dbo.league AS l WITH (NOLOCK) ON l.leagueid = o.leagueid
			WHERE l.sporttype <> 1 AND b.Product = 'Outright'

			-- Parlay
			DELETE b
			FROM @Data AS b
			WHERE b.Product = 'Parlay'
				AND NOT EXISTS (SELECT 1
						FROM dbo.bettransm AS bm WITH (NOLOCK)
							INNER JOIN dbo.match AS m WITH (NOLOCK) ON bm.matchid = m.matchid
						WHERE m.sporttype = 1 AND bm.refno = b.RefNo)
		END
		ELSE IF @Date BETWEEN @BalanceUpDay AND @MoveBetsDay		-- bettrans14 range
		BEGIN
			-- Normal tickets
			DELETE b
			FROM @Data AS b
				INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.MatchId = m.matchid
			WHERE m.sporttype <> 1 AND b.Product = 'SB'

			-- Outright
			DELETE b
			FROM @Data AS b
				INNER JOIN dbo.outright14 AS o WITH (NOLOCK) ON o.orid = b.MatchId
				INNER JOIN dbo.league AS l WITH (NOLOCK) ON l.leagueid = o.leagueid
			WHERE l.sporttype <> 1 AND b.Product = 'Outright'

			-- Parlay
			DELETE b
			FROM @Data AS b
			WHERE b.Product = 'Parlay'
				AND NOT EXISTS (SELECT 1
						FROM dbo.bettransm14 AS bm WITH (NOLOCK)
							INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON bm.matchid = m.matchid
						WHERE m.sporttype = 1 AND bm.refno = b.RefNo)
		END
		ELSE IF @Date < @BalanceUpDay		-- bettrans_bk range
		BEGIN
			-- Normal tickets
			DELETE b
			FROM @Data AS b
				INNER JOIN bodb_Archive.dbo.match_bk AS m WITH (NOLOCK) ON b.MatchId = m.matchid
			WHERE m.sporttype <> 1 AND b.Product = 'SB'

			-- Outright
			DELETE b
			FROM @Data AS b
				INNER JOIN bodb_Archive.dbo.outright_bk AS o WITH (NOLOCK) ON o.orid = b.MatchId
				INNER JOIN dbo.league AS l WITH (NOLOCK) ON l.leagueid = o.leagueid
			WHERE l.sporttype <> 1 AND b.Product = 'Outright'

			-- Parlay
			DELETE b
			FROM @Data AS b
			WHERE b.Product = 'Parlay'
				AND NOT EXISTS (SELECT 1
						FROM bodb_Archive.dbo.bettransm AS bm WITH (NOLOCK)
							INNER JOIN bodb_Archive.dbo.match_bk AS m WITH (NOLOCK) ON bm.matchid = m.matchid
						WHERE m.sporttype = 1 AND bm.refno = b.RefNo)
		END

		IF EXISTS (SELECT 1 FROM @Data)
		BEGIN
			-- Get data for summary ticket of multiple Bonus/Cash sub tickets
			IF EXISTS (SELECT 1 FROM @Data WHERE RefCode <> 0)
			BEGIN
				DECLARE @RefCodeTmp TABLE (
					RefCode			BIGINT,
					TransId			BIGINT,
					Stake			MONEY,
					Actual_Stake	MONEY,
					WinLost			MONEY,
					Commission		MONEY
				)

				-- Prepare temp table
				INSERT INTO @RefCodeTmp
				SELECT
					RefCode,
					MIN(TransId) AS TransId,
					SUM(Stake) AS Stake,
					SUM(Actual_Stake) AS Actual_Stake,
					SUM(WinLost) AS WinLost,
					SUM(Commission) AS Commission
				FROM @Data
				WHERE RefCode <> 0
				GROUP BY RefCode
				HAVING COUNT(*) > 1

				IF EXISTS (SELECT 1 FROM @RefCodeTmp)
				BEGIN
					-- Update data for summmary ticket
					UPDATE b
					SET
						b.Stake = r.Stake,
						b.Actual_Stake = r.Actual_Stake,
						b.WinLost = r.WinLost,
						b.Commission = r.Commission,
						b.WalletType = 0
					FROM @Data AS b
						INNER JOIN @RefCodeTmp AS r ON b.RefCode = r.RefCode AND b.TransId = r.TransId

					-- Delete 2nd Bonus/Cash tickets
					DELETE @Data
					WHERE WalletType <> 0
						AND RefCode IN (SELECT RefCode FROM @RefCodeTmp)
				END
			END

			-- Display detail link for ticket from Bonus Wallet only
			UPDATE @Data
			SET RefCode = TransId
			WHERE WalletType = 1 AND RefCode = 0

			-- Don't display Cash text for ticket from Cash Wallet only
			UPDATE @Data
			SET WalletType = 0
			WHERE WalletType = 2 AND RefCode = 0

			-- bettrans range
			IF @Date > @MoveBetsDay
			BEGIN
				UPDATE b
				SET
					TransId = CASE
								WHEN b.Product = 'Parlay' AND b.bettype = 29 AND ISNULL(b.betid, 0) > 0 THEN b.betid
								ELSE b.transid
							END,
					SportType = CASE
									WHEN b.Product IN ('SB', 'CO') THEN m.sporttype
									WHEN b.Product IN ('Outright') THEN l.sporttype
									ELSE 0
								END,
					BetTeam = CASE
									WHEN b.Product IN ('SB', 'CO', 'Parlay') THEN b.betteam
									ELSE ''
								END,
					Hdp1 = CASE
								WHEN b.Product IN ('SB', 'CO', 'Parlay') THEN b.hdp1
								ELSE 0
							END,
					Hdp2 = CASE
								WHEN b.Product IN ('SB', 'CO', 'Parlay') THEN b.hdp2
								ELSE 0
							END,
					OddsType = CASE
									WHEN b.Product IN ('SB', 'CO') THEN b.oddstype
									ELSE 0
								END,
					Odds = CASE
								WHEN b.Product IN ('SB', 'CO', 'Outright', 'Parlay') THEN b.odds
								ELSE 0
							END,
					MOdds = CASE
								WHEN b.Product IN ('SB', 'CO', 'Outright', 'Parlay') THEN b.modds
								ELSE 0
							END,
					Status = CASE
								WHEN b.Product = 'SB' AND b.bettype NOT IN (9, 29)
									AND b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
								WHEN b.bettype IN (9, 29, 2799) AND b.status = 'running' THEN
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
							END,
					SettlementStatus = CASE
											WHEN b.Product = 'SB' THEN ISNULL(m.SettlementStatus, 0)
											ELSE 0
										END,
					WinLost = b.winlost - b.actual_stake,
					LiveIndicator = CASE
										WHEN b.Product IN ('SB', 'CO') THEN b.liveindicator
										ELSE 0
									END,
					LiveHomeScore = CASE
										WHEN b.Product IN ('SB', 'CO', 'Outright') THEN b.livehomescore
										ELSE 0
									END,
					LiveAwayScore = CASE
										WHEN b.Product IN ('SB', 'CO', 'Outright') THEN b.liveawayscore
										ELSE 0
									END,
					LeagueId = CASE
									WHEN b.Product IN ('SB', 'CO') THEN m.leagueid
									WHEN b.Product IN ('Outright') THEN o.leagueid
									ELSE 0
								END,
					MatchId = CASE
									WHEN b.Product IN ('SB', 'CO') THEN m.matchid
									WHEN b.Product IN ('Outright') THEN o.orid
									ELSE 0
								END,
					MatchCode = CASE
									WHEN b.Product IN ('SB', 'CO') THEN m.matchcode
									WHEN b.Product IN ('Outright') THEN o.matchcode
									ELSE ''
								END,
					Race = CASE
								WHEN b.Product IN ('Outright') THEN o.groupmatch
								ELSE ''
							END,
					EventDate = CASE
									WHEN b.Product IN ('SB', 'CO') THEN m.GlobalShowTime
									WHEN b.Product IN ('Outright') THEN o.eventdate
									ELSE b.winlostdate
								END,
					HomeId = CASE
								WHEN b.Product IN ('SB', 'CO') THEN m.homeid
								WHEN b.Product IN ('Outright') THEN o.teamid
								ELSE 0
							END,
					AwayId = CASE
								WHEN b.Product IN ('SB', 'CO') THEN m.awayid
								ELSE 0
							END,
					IsNeutral = CASE
									WHEN b.Product IN ('SB', 'CO') THEN ISNULL(m.IsNeutral, 0)
									ELSE 0
								END,
					ShowTime = CASE
									WHEN b.Product IN ('SB', 'CO') THEN ISNULL(m.showtime, '')
									ELSE ''
								END,
					BetCheck = CASE
									WHEN b.Product IN ('SB', 'CO', 'Parlay') THEN ISNULL(b.betcheck, '')
									ELSE ''
								END,
					ComStatus = CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END,
					TransDesc = CASE
									WHEN b.Product IN ('SB', 'CO') THEN ISNULL(b.transdesc, '')
									ELSE ''
								END,
					OddsSpread = CASE
									WHEN b.Product IN ('SB', 'CO') THEN ISNULL(b.oddsspread, 0)
									ELSE 0
								END,
					BetdaqId = CASE
									WHEN b.Product IN ('SB', 'CO') THEN ISNULL(b.betdaqid, -1)
									ELSE -1
								END,
					ExtraInfo = CASE
									WHEN b.Product IN ('SB', 'Outright') THEN ISNULL(b.ExtraInfo, '')
									ELSE ''
								END,
					WalletType = CASE
									WHEN b.Product IN ('SB') THEN ISNULL(b.WalletType, 0)
									ELSE 0
								END,
					RefCode = CASE
									WHEN b.Product IN ('SB') THEN ISNULL(b.RefCode, 0)
									ELSE 0
								END
				FROM @Data AS b
					LEFT JOIN dbo.match AS m WITH (NOLOCK) ON b.Product IN ('SB', 'CO') AND b.matchid = m.matchid
					LEFT JOIN dbo.outright AS o WITH (NOLOCK) ON b.Product IN ('Outright') AND b.matchid = o.orid
					LEFT JOIN dbo.League AS l WITH (NOLOCK) ON b.Product IN ('Outright') AND o.leagueid = l.leagueid
				WHERE b.TableID = 1

				-- translog
				UPDATE b
				SET SportType = m.sporttype,
					BetId = 0,
					BetTeam = '',
					Hdp1 = 0,
					Hdp2 = 0,
					OddsType = CONVERT(TINYINT, ISNULL(b.custom1, 0)),
					OddsId = 0,
					MOdds = 0,
					SettlementStatus = ISNULL(m.SettlementStatus, 0),
					WinLost = 0,
					Commission = 0,
					LiveIndicator = 0,
					LiveHomeScore = 0,
					LiveAwayScore = 0,
					LeagueId = m.leagueid,
					MatchId = m.matchid,
					MatchCode = m.matchcode,
					Race = '',
					EventDate = m.GlobalShowTime,
					HomeId = m.homeid,
					AwayId = m.awayid,
					IsNeutral = ISNULL(m.IsNeutral, 0),
					ShowTime = ISNULL(m.showtime, ''),
					BetCheck = '',
					ComStatus = 0,
					TransDesc = b.transdesc,
					OddsSpread = 0,
					BetdaqId = -1,
					ExtraInfo = ''
				FROM @Data AS b
					INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.Product IN ('SB') AND b.eventid = m.matchid
				WHERE TableID = 4
					AND b.BetType BETWEEN 801 AND 806
			END
			ELSE IF @Date BETWEEN @BalanceUpDay AND @MoveBetsDay		-- bettrans14 range
			BEGIN
				UPDATE b
				SET
					TransId = CASE
								WHEN b.Product = 'Parlay' AND b.bettype = 29 AND ISNULL(b.betid, 0) > 0 THEN b.betid
								ELSE b.transid
							END,
					SportType = CASE
									WHEN b.Product IN ('SB', 'CO') THEN m.sporttype
									WHEN b.Product IN ('Outright') THEN l.sporttype
									ELSE 0
								END,
					BetTeam = CASE
									WHEN b.Product IN ('SB', 'CO', 'Parlay') THEN b.betteam
									ELSE ''
								END,
					Hdp1 = CASE
								WHEN b.Product IN ('SB', 'CO', 'Parlay') THEN b.hdp1
								ELSE 0
							END,
					Hdp2 = CASE
								WHEN b.Product IN ('SB', 'CO', 'Parlay') THEN b.hdp2
								ELSE 0
							END,
					OddsType = CASE
									WHEN b.Product IN ('SB', 'CO') THEN b.oddstype
									ELSE 0
								END,
					Odds = CASE
								WHEN b.Product IN ('SB', 'CO', 'Outright', 'Parlay') THEN b.odds
								ELSE 0
							END,
					MOdds = CASE
								WHEN b.Product IN ('SB', 'CO', 'Outright', 'Parlay') THEN b.modds
								ELSE 0
							END,
					SettlementStatus = 0,
					WinLost = b.winlost - b.actual_stake,
					LiveIndicator = CASE
										WHEN b.Product IN ('SB', 'CO') THEN b.liveindicator
										ELSE 0
									END,
					LiveHomeScore = CASE
										WHEN b.Product IN ('SB', 'CO', 'Outright') THEN b.livehomescore
										ELSE 0
									END,
					LiveAwayScore = CASE
										WHEN b.Product IN ('SB', 'CO', 'Outright') THEN b.liveawayscore
										ELSE 0
									END,
					LeagueId = CASE
									WHEN b.Product IN ('SB', 'CO') THEN m.leagueid
									WHEN b.Product IN ('Outright') THEN o.leagueid
									ELSE 0
								END,
					MatchId = CASE
									WHEN b.Product IN ('SB', 'CO') THEN m.matchid
									WHEN b.Product IN ('Outright') THEN o.orid
									ELSE 0
								END,
					MatchCode = CASE
									WHEN b.Product IN ('SB', 'CO') THEN m.matchcode
									WHEN b.Product IN ('Outright') THEN o.matchcode
									ELSE ''
								END,
					Race = CASE
								WHEN b.Product IN ('Outright') THEN o.groupmatch
								ELSE ''
							END,
					EventDate = CASE
									WHEN b.Product IN ('SB', 'CO') THEN m.GlobalShowTime
									WHEN b.Product IN ('Outright') THEN o.eventdate
									ELSE b.winlostdate
								END,
					HomeId = CASE
								WHEN b.Product IN ('SB', 'CO') THEN m.homeid
								WHEN b.Product IN ('Outright') THEN o.teamid
								ELSE 0
							END,
					AwayId = CASE
								WHEN b.Product IN ('SB', 'CO') THEN m.awayid
								ELSE 0
							END,
					IsNeutral = CASE
									WHEN b.Product IN ('SB', 'CO') THEN ISNULL(m.IsNeutral, 0)
									ELSE 0
								END,
					ShowTime = CASE
									WHEN b.Product IN ('SB', 'CO') THEN ISNULL(m.showtime, '')
									ELSE ''
								END,
					BetCheck = CASE
									WHEN b.Product IN ('SB', 'CO', 'Parlay') THEN ISNULL(b.betcheck, '')
									ELSE ''
								END,
					ComStatus = CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END,
					TransDesc = CASE
									WHEN b.Product IN ('SB', 'CO') THEN ISNULL(b.transdesc, '')
									ELSE ''
								END,
					OddsSpread = CASE
									WHEN b.Product IN ('SB', 'CO') THEN ISNULL(b.oddsspread, 0)
									ELSE 0
								END,
					BetdaqId = CASE
									WHEN b.Product IN ('SB', 'CO') THEN ISNULL(b.betdaqid, -1)
									ELSE -1
								END,
					ExtraInfo = CASE
									WHEN b.Product IN ('SB', 'Outright') THEN ISNULL(b.ExtraInfo, '')
									ELSE ''
								END,
					WalletType = CASE
									WHEN b.Product IN ('SB') THEN ISNULL(b.WalletType, 0)
									ELSE 0
								END,
					RefCode = CASE
									WHEN b.Product IN ('SB') THEN ISNULL(b.RefCode, 0)
									ELSE 0
								END
				FROM @Data AS b
					LEFT JOIN dbo.match14 AS m WITH (NOLOCK) ON b.Product IN ('SB', 'CO') AND b.matchid = m.matchid
					LEFT JOIN dbo.outright14 AS o WITH (NOLOCK) ON b.Product IN ('Outright') AND b.matchid = o.orid
					LEFT JOIN dbo.League AS l WITH (NOLOCK) ON b.Product IN ('Outright') AND o.leagueid = l.leagueid
				WHERE b.TableID = 2
			END
			ELSE IF @Date < @BalanceUpDay		-- bettrans_bk range
			BEGIN
				UPDATE b
				SET
					TransId = CASE
								WHEN b.Product = 'Parlay' AND b.bettype = 29 AND ISNULL(b.betid, 0) > 0 THEN b.betid
								ELSE b.transid
							END,
					SportType = CASE
									WHEN b.Product IN ('SB', 'CO') THEN m.sporttype
									WHEN b.Product IN ('Outright') THEN l.sporttype
									ELSE 0
								END,
					BetTeam = CASE
									WHEN b.Product IN ('SB', 'CO', 'Parlay') THEN b.betteam
									ELSE ''
								END,
					Hdp1 = CASE
								WHEN b.Product IN ('SB', 'CO', 'Parlay') THEN b.hdp1
								ELSE 0
							END,
					Hdp2 = CASE
								WHEN b.Product IN ('SB', 'CO', 'Parlay') THEN b.hdp2
								ELSE 0
							END,
					OddsType = CASE
									WHEN b.Product IN ('SB', 'CO') THEN b.oddstype
									ELSE 0
								END,
					Odds = CASE
								WHEN b.Product IN ('SB', 'CO', 'Outright', 'Parlay') THEN b.odds
								ELSE 0
							END,
					MOdds = CASE
								WHEN b.Product IN ('SB', 'CO', 'Outright', 'Parlay') THEN b.modds
								ELSE 0
							END,
					SettlementStatus = 0,
					WinLost = b.winlost - b.actual_stake,
					LiveIndicator = CASE
										WHEN b.Product IN ('SB', 'CO') THEN b.liveindicator
										ELSE 0
									END,
					LiveHomeScore = CASE
										WHEN b.Product IN ('SB', 'CO', 'Outright') THEN b.livehomescore
										ELSE 0
									END,
					LiveAwayScore = CASE
										WHEN b.Product IN ('SB', 'CO', 'Outright') THEN b.liveawayscore
										ELSE 0
									END,
					LeagueId = CASE
									WHEN b.Product IN ('SB', 'CO') THEN m.leagueid
									WHEN b.Product IN ('Outright') THEN o.leagueid
									ELSE 0
								END,
					MatchId = CASE
									WHEN b.Product IN ('SB', 'CO') THEN m.matchid
									WHEN b.Product IN ('Outright') THEN o.orid
									ELSE 0
								END,
					MatchCode = CASE
									WHEN b.Product IN ('SB', 'CO') THEN m.matchcode
									WHEN b.Product IN ('Outright') THEN o.matchcode
									ELSE ''
								END,
					Race = CASE
								WHEN b.Product IN ('Outright') THEN o.groupmatch
								ELSE ''
							END,
					EventDate = CASE
									WHEN b.Product IN ('SB', 'CO') THEN m.GlobalShowTime
									WHEN b.Product IN ('Outright') THEN o.eventdate
									ELSE b.winlostdate
								END,
					HomeId = CASE
								WHEN b.Product IN ('SB', 'CO') THEN m.homeid
								WHEN b.Product IN ('Outright') THEN o.teamid
								ELSE 0
							END,
					AwayId = CASE
								WHEN b.Product IN ('SB', 'CO') THEN m.awayid
								ELSE 0
							END,
					IsNeutral = CASE
									WHEN b.Product IN ('SB', 'CO') THEN ISNULL(m.IsNeutral, 0)
									ELSE 0
								END,
					ShowTime = CASE
									WHEN b.Product IN ('SB', 'CO') THEN ISNULL(m.showtime, '')
									ELSE ''
								END,
					BetCheck = CASE
									WHEN b.Product IN ('SB', 'CO', 'Parlay') THEN ISNULL(b.betcheck, '')
									ELSE ''
								END,
					ComStatus = CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END,
					TransDesc = CASE
									WHEN b.Product IN ('SB', 'CO') THEN ISNULL(b.transdesc, '')
									ELSE ''
								END,
					OddsSpread = CASE
									WHEN b.Product IN ('SB', 'CO') THEN ISNULL(b.oddsspread, 0)
									ELSE 0
								END,
					BetdaqId = CASE
									WHEN b.Product IN ('SB', 'CO') THEN ISNULL(b.betdaqid, -1)
									ELSE -1
								END,
					ExtraInfo = CASE
									WHEN b.Product IN ('SB', 'Outright') THEN ISNULL(b.ExtraInfo, '')
									ELSE ''
								END,
					WalletType = CASE
									WHEN b.Product IN ('SB') THEN ISNULL(b.WalletType, 0)
									ELSE 0
								END,
					RefCode = CASE
									WHEN b.Product IN ('SB') THEN ISNULL(b.RefCode, 0)
									ELSE 0
								END
				FROM @Data AS b
					LEFT JOIN bodb_Archive.dbo.match_bk AS m WITH (NOLOCK) ON b.Product IN ('SB', 'CO') AND b.matchid = m.matchid
					LEFT JOIN bodb_Archive.dbo.outright_bk AS o WITH (NOLOCK) ON b.Product IN ('Outright') AND b.matchid = o.orid
					LEFT JOIN dbo.League AS l WITH (NOLOCK) ON b.Product IN ('Outright') AND o.leagueid = l.leagueid
				WHERE b.TableID = 3
			END
		END
	END

	-- Get currency name
	DECLARE @CurrencyName NVARCHAR(50)

	SELECT @CurrencyName = ex.currency
	FROM dbo.custInfo AS ci WITH (NOLOCK)
		INNER JOIN dbo.Exchange AS ex WITH (NOLOCK) ON ci.currency = ex.exchangeid
	WHERE ci.custid = @CustId

	SELECT
		b.TransId,
		b.RefNo,
		b.CustId,
		b.SportType,
		b.BetType,
		b.BetId,
		b.BetTeam,
		b.Hdp1,
		b.Hdp2,
		b.OddsId,
		b.OddsType,
		b.Odds,
		b.MOdds,
		b.OddsSpread,
		b.Stake,
		b.Actual_Stake,
		b.WinLost,
		b.Commission,
		b.Status,
		b.SettlementStatus,
		b.TransDate,
		b.WinLostDate,
		b.LiveIndicator,
		b.LiveHomeScore,
		b.LiveAwayScore,
		b.Ip,
		b.BetFrom,
		b.LeagueId,
		b.MatchId,
		b.MatchCode,
		b.Race,
		b.EventDate,
		b.HomeId,
		b.AwayId,
		b.IsNeutral,
		b.ShowTime,
		b.BetCheck,
		b.ComStatus,
		b.TransDesc,
		b.BetdaqId,
		b.ExtraInfo,
		b.OriginalBetType,
		b.WalletType,
		b.RefCode,
		@CurrencyName AS Currency,
		u.username AS Username,
		c.username AS Creator
	FROM @Data AS b
		INNER JOIN dbo.custInfo AS u WITH (NOLOCK) ON u.custid = b.CustId
		INNER JOIN dbo.custInfo AS c WITH (NOLOCK) ON c.custid = b.Creator
	ORDER BY b.TransId ASC

	SELECT DISTINCT * FROM @DetailData
END
GO




GRANT EXECUTE ON [dbo].[Acc_BetListByIP_Soccer] TO [bodbAdminNet]
GO
