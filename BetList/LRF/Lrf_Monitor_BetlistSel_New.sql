/*<info serverAlias="DB042-bodb02" executers="bodbLicenseeNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_Monitor_BetlistSel_New]
	@AgentList		VARCHAR(MAX),
	@BetType		VARCHAR(50)		= '',
	@Currency		VARCHAR(200)	= '',
	@SpecialLevel	VARCHAR(200)	= '',
	@TransId		BIGINT			= 0,
	@LimitRowCount	INT				= 10,
	@SportId		INT				= 0,
	@LeagueId		INT				= 0,
	@MatchId		INT				= 0,
	@MinStake		MONEY			= 0,
	@MaxStake		MONEY			= 0,
	@LiveIndicator	INT				= 0,
	@BetFrom		TINYINT			= 0,
	@BaseCurrency	VARCHAR(10)		='USD',
	@Debug			BIT				= 0
AS

/*
	Created: Scott@20130418
	Task: LRF Monitor lastest bets list(all bettypes and all sports) with filter by League and Sport
	DB: DB042.bodb02
	Original: [Lrf_Monitor_BetlistSel]
	Revision:
		- 20130618@Jim: Restrict permission of Licensee Users by currency
		- 20130806@Jim: Add betting platform to Last bets monitoring
		- 20140620@Florent: Offer Sporting Solution (36 new bettypes)
		- 20141021@Florent: Apply for the change in Sporting Solution structure (#24478)
		- 20141120@Jim: Expand data range for @TransId param to covert big datatype
		- 20150128@Jim: base on GBP
		- 20150415@Jim: Support betradar
		- 20151210@Kos: Support PH All In One 4 new bet types 401, 402, 403, 404 (O/U bettypes)
		- 20160115@Joseph: Redefine values of parameter betfrom
		- 20160413@Kos: Support Combo Parlay [#Redmine: 55282]
		- 20160919@Kos: Add column transdesc to support PH AIO phase 2b [#Redmine: 62878]
		- 20170307@Kos: Support sub licensees [#Redmine: 71679]
		- 20170331@Kos: Support CashOut [#Redmine: 71963]
		- 20170419@Kos: Support BAIO [#Redmine: 73030]
		- 20170803@Kos: Support more betfrom value [#Redmine: 80687]
		- 20170920@Kos: Support new bet types 461-464 [#Redmine: 83260]
		- 20171020@Kos: Support new platform New Asia [#Redmine: 85203]
		- 20171031@Kos: Support Licensee Bonus System [#Redmine: 72792]
		- 20180319@Kos: Support Fast Market 2 [#Redmine: 90879]
		- 20180817@Kos: Migrate to DB042 [RedmineID: #99464]
		- 20180823@Kos: HotFix - Miss SpecialLevel [RedmineID: #100423]
		- 20180903@Kos: Remove dynamic SQL [RedmineID: #101703]
					- Remove param @IncludeBetFrom
					- Change base currency coding style, support all base currencies
		- 20181114@Kos: Change getting ticket status [#Redmine: 104664]
		- 20181121@Kos: Support new platform Mobile App [#Redmine: 104521]

	Parameter's Explanation:
		- @BetType:
			+ HDP: 1, 7, 1303, 17, 183, 609
			+ OU: 3, 18, 8, 178, 1306, 401, 402, 403, 404, 461, 462, 463, 464, 610, 615, 616
			+ Others: NOT IN 1, 3, 7, 8, 17, 18, 178, 183, 1303, 1306, 401, 402, 403, 404, 461, 462, 463, 464
			+ ALL: <= 19000
		- @TransId: lastest transid
		- @LimitRowCount: max record return (10,20,30)
		- @SportId = 999 -> Parlay and System Parlay
		- @LiveIndicator (0 : non live, 1 : live , 2 : mix non live & live)
		- @IncludeBetFrom: 1: show column betfrom, 0: hide
		- @BetFrom: 0 - All: All
					1 - Asia: d (mobile), g (MG Download only)
					2 - China: a (dep-Singbet), z (dep2-SingBet)
					3 - Euro: e (Europe), u (dep-Euro), y (dep2-Euro)
					4 - WAP: m (dep-wap)
					5 - Smart Site: s (smartphone), l (dep-smart)
					6 - Tablet: r (dep2-tablet)
					7 - New Asia: x (dep2-Asia)
					8 - Mobile App: o (dep-New Mobile APP)
	Excecute sample :
		[Lrf_Monitor_BetlistSel_New]
			@LicenseeID = 14,
			@BetType='HDP',
			@LicenseeType='Normal',
			@Currency='1,2,3,4,5,6,7,8,9,10',
			@SpecialLevel='0,1,2,3,4,5,6,7,8,9',
			@TransId=0,
			@LimitRowCount=10,
			@SportId=1,
			@LeagueId=3,
			@Matchid=3874470,
			@MinStake=100,
			@LiveIndicator=0
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @HasError BIT = 0

	DECLARE @TempAg TABLE (CustId INT, Currency INT)

	-- Get AgentList
	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT, @AgentList
	
		INSERT INTO @TempAg (CustId, Currency)
		SELECT AgentId, Currency
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId INT, Currency INT) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY
	BEGIN CATCH
		SET @HasError = 1
	END CATCH

	DECLARE @Data TABLE (
		CustId			INT,
		MatchId			INT,
		BetType			SMALLINT,
		ProductId		TINYINT,
		TransId			BIGINT,
		RefNo			BIGINT,
		TransDate		DATETIME,
		BetId			BIGINT,
		LiveHomeScore	SMALLINT,
		LiveAwayScore	SMALLINT,
		LiveIndicator	INT,
		Hdp1			SMALLMONEY,
		Hdp2			SMALLMONEY,
		Odds			MONEY,
		Actual_Stake	MONEY,
		Stake			MONEY,
		BetFrom			NVARCHAR(1),
		Status			NVARCHAR(10),
		BetTeam			NVARCHAR(10),
		OddsType		TINYINT,
		CurrencyId		SMALLINT,
		SpecialLevel	INT,
		BetCheck		NVARCHAR(100),
		TransDesc		NVARCHAR(1000),
		BetdaqId		BIGINT,
		ExtraInfo		VARCHAR(1000),
		OriginalStake	MONEY,
		OriginalBetType	SMALLINT,
		WalletType		TINYINT,
		RefCode			BIGINT,
		OddsSpread		MONEY
	)

	DECLARE @ExchangeRate TABLE (
		ExchangeId	INT,
		Rate		FLOAT
	)

	IF @HasError = 0
	BEGIN
		IF @MinStake IS NULL
			SET @MinStake = 0

		IF @MaxStake IS NULL
			SET @MaxStake = 0

		DECLARE @BetFromList VARCHAR(50)

		IF @BetFrom = 1
		BEGIN
			SET @BetFromList = 'd,g'
		END
		ELSE IF @BetFrom = 2
		BEGIN
			SET @BetFromList = 'a,z'
		END
		ELSE IF @BetFrom = 3
		BEGIN
			SET @BetFromList = 'e,u,y'
		END
		ELSE IF @BetFrom = 4
		BEGIN
			SET @BetFromList = 'm'
		END
		ELSE IF @BetFrom = 5
		BEGIN
			SET @BetFromList = 's,l'
		END
		ELSE IF @BetFrom = 6
		BEGIN
			SET @BetFromList = 'r'
		END
		ELSE IF @BetFrom = 7
		BEGIN
			SET @BetFromList = 'x'
		END
		ELSE IF @BetFrom = 8
		BEGIN
			SET @BetFromList = 'o'
		END

		-- Check if @TransId and @TransId + 1 is combo ticket then reset @TransId
		DECLARE @RefCode	BIGINT

		SELECT @RefCode = RefCode
		FROM dbo.bettrans WITH (NOLOCK)
		WHERE transid = @TransId

		IF @RefCode IS NOT NULL AND @RefCode > 0
		BEGIN
			IF EXISTS (	SELECT 1 FROM dbo.bettrans WITH (NOLOCK)
						WHERE transid = @TransId + 1 AND RefCode = @RefCode )
			BEGIN
				SET @TransId = @TransId + 1
			END
		END

		IF @SportId = 0
		BEGIN
			INSERT INTO @Data
			SELECT
				b.custid,
				b.matchid,
				b.bettype,
				0 AS ProductId,
				b.transid,
				b.refno,
				b.transdate,
				b.betid,
				b.livehomescore,
				b.liveawayscore,
				b.liveindicator,
				b.hdp1,
				b.hdp2,
				b.odds,
				b.actual_stake,
				b.stake,
				b.betfrom,
				CASE
					WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
					ELSE b.status
				END AS status,
				b.betteam,
				b.oddstype,
				b.currency AS CurrencyId,
				0 AS SpecialLevel,
				ISNULL(b.betcheck, '') AS BetCheck,
				ISNULL(b.transdesc, '') AS TransDesc,
				ISNULL(b.betdaqid, -1) AS BetdaqId,
				ISNULL(b.ExtraInfo, '') AS ExtraInfo,
				CASE
					WHEN b.ExtraInfo LIKE '%p25%' THEN
						ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p25/@s)[1]','MONEY'), 0)
					ELSE 0
				END AS OriginalStake,
				CASE
					WHEN b.stake <> 0 THEN -1
					ELSE 0
				END AS OriginalBetType,
				ISNULL(b.WalletType, 0) AS WalletType,
				ISNULL(b.RefCode, 0) AS RefCode,
				ISNULL(b.oddsspread, 0) AS OddsSpread
			FROM dbo.bettrans AS b WITH (NOLOCK, INDEX = IX_monitor_recommend)
				INNER JOIN @TempAg AS a ON b.Recommend = a.CustId AND b.Currency = a.Currency
			WHERE b.statusID IN (0, 1)
				AND b.transid > @TransId
				AND (@BetFrom = 0
					OR ',' + @BetFromList + ',' LIKE '%,' + b.betfrom + ',%')
				AND (@Currency = ''
					OR ',' + @Currency + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.currency) + ',%')
				AND (@LiveIndicator = 3
					OR (b.bettype IN (9, 29) AND b.livehomescore = @LiveIndicator)
					OR (b.bettype NOT IN (9, 29) AND @LiveIndicator IN (0, 1) AND b.liveindicator = @LiveIndicator))
				AND (@BetType = ''
					OR (@BetType = 'HDP' AND b.bettype IN (1, 7, 1303, 17, 183, 609))
					OR (@BetType = 'OU' AND b.bettype IN (3, 18, 8, 178, 1306, 401, 402, 403, 404, 461, 462, 463, 464, 610, 615, 616))
					OR (@BetType = 'Others' AND b.bettype NOT IN (1, 3, 7, 8, 17, 18, 178, 183, 1303, 1306, 401, 402, 403, 404, 461, 462, 463, 464, 609, 610, 615, 616)))
		END
		ELSE IF @SportId = 999
		BEGIN
			INSERT INTO @Data
			SELECT
				b.custid,
				b.matchid,
				b.bettype,
				0 AS ProductId,
				b.transid,
				b.refno,
				b.transdate,
				b.betid,
				b.livehomescore,
				b.liveawayscore,
				b.liveindicator,
				b.hdp1,
				b.hdp2,
				b.odds,
				b.actual_stake,
				b.stake,
				b.betfrom,
				b.status,
				b.betteam,
				b.oddstype,
				b.currency AS CurrencyId,
				0 AS SpecialLevel,
				ISNULL(b.betcheck, '') AS BetCheck,
				ISNULL(b.transdesc, '') AS TransDesc,
				ISNULL(b.betdaqid, -1) AS BetdaqId,
				ISNULL(b.ExtraInfo, '') AS ExtraInfo,
				CASE
					WHEN b.ExtraInfo LIKE '%p25%' THEN
						ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p25/@s)[1]','MONEY'), 0)
					ELSE 0
				END AS OriginalStake,
				CASE
					WHEN b.stake <> 0 THEN -1
					ELSE 0
				END AS OriginalBetType,
				ISNULL(b.WalletType, 0) AS WalletType,
				ISNULL(b.RefCode, 0) AS RefCode,
				ISNULL(b.oddsspread, 0) AS OddsSpread
			FROM dbo.bettrans AS b WITH (NOLOCK, INDEX = IX_monitor_recommend)
				INNER JOIN @TempAg AS a ON b.Recommend = a.CustId AND b.Currency = a.Currency
			WHERE b.statusID IN (0, 1)
				AND b.transid > @TransId
				AND b.bettype IN (9, 29)
				AND (@BetFrom = 0
					OR ',' + @BetFromList + ',' LIKE '%,' + b.betfrom + ',%')
				AND (@Currency = ''
					OR ',' + @Currency + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.currency) + ',%')
				AND (@LiveIndicator = 3 OR b.livehomescore = @LiveIndicator)
		END
		ELSE IF @SportId > 0 AND @SportId < 999
		BEGIN
			INSERT INTO @Data
			SELECT
				b.custid,
				b.matchid,
				b.bettype,
				0 AS ProductId,
				b.transid,
				b.refno,
				b.transdate,
				b.betid,
				b.livehomescore,
				b.liveawayscore,
				b.liveindicator,
				b.hdp1,
				b.hdp2,
				b.odds,
				b.actual_stake,
				b.stake,
				b.betfrom,
				CASE
					WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
					ELSE b.status
				END AS status,
				b.betteam,
				b.oddstype,
				b.currency AS CurrencyId,
				0 AS SpecialLevel,
				ISNULL(b.betcheck, '') AS BetCheck,
				ISNULL(b.transdesc, '') AS TransDesc,
				ISNULL(b.betdaqid, -1) AS BetdaqId,
				ISNULL(b.ExtraInfo, '') AS ExtraInfo,
				CASE
					WHEN b.ExtraInfo LIKE '%p25%' THEN
						ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p25/@s)[1]','MONEY'), 0)
					ELSE 0
				END AS OriginalStake,
				CASE
					WHEN b.stake <> 0 THEN -1
					ELSE 0
				END AS OriginalBetType,
				ISNULL(b.WalletType, 0) AS WalletType,
				ISNULL(b.RefCode, 0) AS RefCode,
				ISNULL(b.oddsspread, 0) AS OddsSpread
			FROM dbo.bettrans AS b WITH (NOLOCK, INDEX = IX_monitor_recommend)
				INNER JOIN @TempAg AS a ON b.Recommend = a.CustId AND b.Currency = a.Currency
			WHERE b.statusID IN (0, 1)
				AND b.transid > @TransId
				AND b.bettype NOT IN (9, 29)
				AND (@BetFrom = 0
					OR ',' + @BetFromList + ',' LIKE '%,' + b.betfrom + ',%')
				AND (@Currency = ''
					OR ',' + @Currency + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.currency) + ',%')
				AND (@LiveIndicator = 3
					OR (@LiveIndicator IN (0, 1) AND b.liveindicator = @LiveIndicator))
				AND (@BetType = ''
					OR (@BetType = 'HDP' AND b.bettype IN (1, 7, 1303, 17, 183, 609))
					OR (@BetType = 'OU' AND b.bettype IN (3, 18, 8, 178, 1306, 401, 402, 403, 404, 461, 462, 463, 464, 610, 615, 616))
					OR (@BetType = 'Others' AND b.bettype NOT IN (1, 3, 7, 8, 17, 18, 178, 183, 1303, 1306, 401, 402, 403, 404, 461, 462, 463, 464, 609, 610, 615, 616)))
		END

		IF EXISTS (SELECT TOP(1) 1 FROM @Data)
		BEGIN
			IF @SportId >= 0 AND @SportId < 999
			BEGIN
				DECLARE @IsTest BIT

				SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

				UPDATE b
				SET ProductId = s.ProductID
				FROM @Data AS b
					INNER JOIN dbo.f_SportBettypeMatrixByProduct_Sel ('1', @IsTest) AS s ON b.bettype = s.bettype

				DELETE @Data WHERE ProductId <> 1
			END

			IF @SportId > 0 AND @SportId < 999
			BEGIN
				DELETE b
				FROM @Data AS b
				WHERE NOT EXISTS (SELECT TOP(1) 1 FROM dbo.match AS m WITH (NOLOCK)
								WHERE m.matchid = b.matchid
									AND m.sporttype = @SportId
									AND m.eventstatus = 'running'
									AND (@LeagueId = 0 OR m.leagueid = @LeagueId)
									AND (@MatchId = 0 OR m.matchid = @MatchId))
					AND NOT EXISTS (SELECT TOP(1) 1 FROM (SELECT orid, leagueid FROM dbo.outright WITH (NOLOCK) WHERE oddsstatus = 'running') AS o
								CROSS APPLY (SELECT l.leagueid FROM dbo.League AS l WITH (NOLOCK) WHERE o.leagueid = l.leagueid AND l.sporttype = @SportId) AS l2
								WHERE o.orid = b.matchid
									AND (@LeagueId = 0 OR o.leagueid = @LeagueId)
									AND (@MatchId = 0 OR o.orid = @MatchId))
			END

			UPDATE b
			SET b.SpecialLevel = ISNULL(d.SpecialLevel, 0)
			FROM @Data AS b
				INNER JOIN dbo.Dep_CustSpecialLevel AS d WITH (NOLOCK) ON b.custid = d.custid

			IF @SpecialLevel <> ''
			BEGIN
				DELETE @Data
				WHERE ',' + @SpecialLevel + ',' NOT LIKE '%,' + CONVERT(VARCHAR(3), SpecialLevel) + ',%'
			END
		END

		-- Get data for summary ticket of multiple Bonus/Cash sub tickets
		IF EXISTS (SELECT 1 FROM @Data WHERE RefCode <> 0)
		BEGIN
			DECLARE @RefCodeTmp TABLE (
				RefCode			BIGINT,
				TransId			BIGINT,
				Stake			MONEY,
				Actual_Stake	MONEY
			)

			-- Prepare temp table
			INSERT INTO @RefCodeTmp
			SELECT
				RefCode,
				MIN(TransId) AS TransId,
				SUM(Stake) AS Stake,
				SUM(Actual_Stake) AS Actual_Stake
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

		-- Get exchange rate
		IF @BaseCurrency <> ''
		BEGIN
			INSERT INTO @ExchangeRate
			SELECT
				e.ExchangeId,
				CASE
					WHEN @BaseCurrency = 'MYR' THEN e.MYR
					WHEN @BaseCurrency = 'USD' THEN e.USD
					WHEN @BaseCurrency = 'EUR' THEN e.EUR
					WHEN @BaseCurrency = 'CNY' THEN e.CNY
					WHEN @BaseCurrency = 'IDR' THEN e.IDR
					WHEN @BaseCurrency = 'GBP' THEN e.GBP
					WHEN @BaseCurrency = 'THB' THEN e.THB
					ELSE 1
				END AS Rate
			FROM dbo.Lrf_f_GetExchangeDaily(CONVERT(VARCHAR(10), GETDATE(), 111), CONVERT(VARCHAR(10), GETDATE(), 111)) AS e
		END
	END

	SELECT 
		c.username,
		SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1, LEN(c.username2) - CHARINDEX('$', c.username2)) AS Nickname,
		b.CustId,
		b.MatchId,
		b.BetType,
		b.TransId,
		b.RefNo,
		b.TransDate,
		b.BetId,
		b.LiveHomeScore,
		b.LiveAwayScore,
		b.LiveIndicator,
		b.Hdp1,
		b.Hdp2,
		b.Odds,
		b.Actual_Stake * ISNULL(b.Rate, 1) AS Actual_Stake,
		b.Stake * ISNULL(b.Rate, 1) AS Stake,
		b.BetFrom,
		b.Status,
		b.BetTeam,
		b.OddsType,
		b.CurrencyId,
		b.SpecialLevel,
		b.BetCheck,
		b.TransDesc,
		b.BetdaqId,
		b.ExtraInfo,
		b.OriginalStake * ISNULL(b.Rate, 1) AS OriginalStake,
		b.OriginalBetType,
		b.WalletType,
		b.RefCode,
		b.OddsSpread
	FROM
		(
			SELECT TOP(@LimitRowCount)
				d.*,
				e.Rate
			FROM @Data AS d
				LEFT JOIN @ExchangeRate AS e ON e.exchangeid = d.CurrencyId
			WHERE (@MinStake = 0 OR d.Stake * ISNULL(e.Rate, 1) >= @MinStake)
				AND (@MaxStake = 0 OR d.Stake * ISNULL(e.Rate, 1) <= @MaxStake)
			ORDER BY d.TransId DESC
		) AS b
		LEFT JOIN dbo.Customer AS c WITH (NOLOCK) ON b.CustId = c.custid
	ORDER BY b.TransId DESC
END






GO
GRANT EXECUTE ON [dbo].[Lrf_Monitor_BetlistSel_New] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_Monitor_BetlistSel_New] TO [vnteam]
GO
