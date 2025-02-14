/*<info serverAlias="DBACC-bodb02" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_BetList_RefNo_Mem]
	@AgentList			VARCHAR(MAX),
	@RefNo				BIGINT			= 0,
	@TxId				VARCHAR(100)	= '',
	@CustId				INT				= 0,
	@Username			VARCHAR(50)		= '',
	@ExcludeBettrans	BIT				= 0,
	@ViewSabaCoins		BIT				= 0,
	@MoveBetsDay		SMALLDATETIME,
	@BalanceUpDay		SMALLDATETIME,
	@BaseCurrency		VARCHAR(12)		= ''
AS

/*
	Created: Kos@20180604
	Task: Betting Ticket Center - Search By RefNo
	DB: DBACC.bodb02
	Revisions:
		- 20180604@Kos: Created [#Redmine: 80941]
		- 20181011@Kos: Fix Licensee WL of Ba tickets [#Redmine: 80941]
		- 20181102@Kos: Remove DBLIC linked server [#Redmine: 103660]
		- 20181114@Kos: Change getting ticket status [#Redmine: 104664]
		- 20190107@Kos: Support Parlay Changes [#Redmine: 107165]
		- 20190121@Kos: Betting Ticket Center phase 3a [Redmine: #103555]
		- 20190426@Kos: Support base currency INH [Redmine: #112603]
		- 20190509@Kos: Show match KO time for single ticket [Redmine: #112731]
					- Return additional column EventDate DATETIME
		- 20190627@Kos: Support PH AIO 4a [Redmine: #115448]
		- 20190730@Kos: Support new status Pending [#Redmine: 117729]
		- 20191018@Kos: Support other products [#Redmine: 122267]
		- 20191031@Kos: Show Running status for Marked tickets [Redmine: #120309]
		- 20191128@Kos: Hotfix - Change oddsspread data type from SMALLMONEY to MONEY [Redmine: #124483]
		- 20191205@Kos: Support Saba Promotion [Redmine: #124612]
		- 20191209@Kos: Support Spadegaming [Redmine: #124103]
		- 20200207@Kos: Support sort by trans time [Redmine: #126886]
		- 20200221@Kos: Support Virtual Games [Redmine: #124911]
		- 20200402@Kos: Support Table Games [Redmine: #131447]
		- 20200416@Kos: Support Indo 4D [Redmine: #130859]
		- 20200502@Kos: Support Table Game Half Won Half Lose [Redmine: #133323]
		- 20200511@Kos: Support Sexy Gaming [Redmine: #130859]
		- 20200518@Kos: Support Saba.club [Redmine: #132702]
		- 20200525@Kos: Support show licensee transaction ID [Redmine: #134629]
		- 20200623@Kos: Integrate archive process for table VSRaceInfo [Redmine: #136285]
		- 20200709@Kos: Support PP Jackpot [Redmine: #137290]
		- 20200731@Kos: Support Saba.club Result [Redmine: #137680]
		- 20200821@Kos: Support SA Gaming [Redmine: #128493]
		- 20201023@Kos: Support PG Soft [Redmine: #139182]
		- 20201123@Kos: Support Joker [Redmine: #141408]
		- 20201210@Kos: Exclude bettype 999 Odds Spread Adjustment [Redmine: #142532]
		- 20201231@Kos: Support Happy 5 Linked Games [Redmine: #147446]
		- 20210112@Kos: Support GDG [Redmine: #147267]
		- 20210118@Kos: Support Saba.club Jackpot Contribution and Jackpot Prize tickets [Redmine: #148100]
		- 20210304@Kos: Hotfix - Wrong data for Saba.club Jackpot Contribution and Jackpot Prize tickets [Redmine: #151158]
		- 20210309@Kos: Add BDT and INR as base currencies [Redmine: 150375]
		- 20210311@Kos: Support Sports Lottery [Redmine: #150872]
		- 20210415@Kos: Support Habanero [Redmine: #150843]
		- 20210506@Kos: Support WM Live Casino [Redmine: #140944]
		- 20210519@Kos: Wrong betteam length [Redmine: #155464]
		- 20210520@Kos: Support Big Gaming [Redmine: #146773]
		- 20210524@Kos: Support Vgaming [Redmine: #151583]
		- 20210705@Kos: Support Happy 5 Linked Games - Soccer 5 [Redmine: #154898]
		- 20210714@Kos: Support CG [Redmine: #152619]
		- 20210917@Kos: Support search by licensee TxId [Redmine: #161706]
					- Add new input param @TxId VARCHAR(100)
		- 20210929@Kos: Extend length to support IPv6 [Redmine: 162342]
		- 20211029@Kos: Decompress IP in bk range [Redmine: 162342]
		- 20211102@Kos: Support AdvantPlay and AdvantPlay Mini [Redmine: #158186]
		- 20220113@Kos: Support new 3rd result API [Redmine: #166047]
		- 20220215@Kos: Hotfix - Vgaming result [Redmine: #168552]
		- 20220215@Kos: Support TxId for 3rd products [Redmine: #166706]
		- 20220217@Kos: Support SG Jackpot [Redmine: #167035]
		- 20220227@Kos: Support Virtual Sports 3 [Redmine: #145337]
		- 20220401@Kos: Support TxId for Vgaming [Redmine: #170054]
		- 20220427@Kos: Support Virtual Games result [Redmine: #170997]
		- 20220428@Kos: Support Bitcoin [RedmineID: #160160]
		- 20220512@Kos: Support FGG [Redmine: #167897]
		- 20220527@Kos: Support MaxGame [RedmineID: #172919]
		- 20220727@Kos: Scale out DBTRANS [Redmine: #175297]
					- Add new input param @ExcludeBettrans BIT
		- 20220922@Kos: Support crypto currency [Redmine: 177481]
		- 20221116@Kos: Support Player Tips [Redmine: 180590]
		- 20230119@Kos: Support Jili [Redmine: 182914]
		- 20230328@Kos: Remove inactive products CB, FW, GDG [Redmine: 181424]
		- 20230404@Kos: Extend betfrom length [Redmine: #178059]
		- 20230524@Kos: Hotfix - Slow when input username [Redmine: #188737]
		- 20230602@Kos: Support YeeBet [Redmine: 187947]
		- 20230629@Kos: Support MG-RNG [Redmine: 189988]
		- 20230905@Kos: Support TxId for MaxGame [Redmine: 193273]
		- 20231019@Kos: Adjust due to new column ExtraInfo [Redmine: 195780]
					- Return new JackpotInfo column
		- 20231026@Kos: Support Virtual Sports 3 [Redmine: 190908]
		- 20231107@Kos: Support SEAL Entertaiment [Redmine: 180648]
		- 20231110@Kos: Support WE Live Casino [Redmine: 196573]
		- 20231227@Kos: Hotfix - cannot view result [Redmine: 198900]
		- 20231227@Kos: Hide Saba text for Jollysports licensees [Redmine: 198697]
		- 20231228@Kos: Support Saba Reward [Redmine: 196882]
		- 20240102@Kos: Extend data type [Redmine: 198966]
		- 20240412@Kos: Support Gaming API [Redmine: 203734]
		- 20240417@Kos: Support Saba Coins [Redmine: 202281]
		- 20240425@Kos: Support Virtual Sports 4 [Redmine: 199347]
		- 20240619@Kos: Hotfix - Missing TranId3rd for Sports Lottery and Virtual Games [Redmine: 206758]
		- 20240919@Kos: Support BetRadar Horse Racing [Redmine: #210808]
		- 20241018@Kos: Enhance match info for Player Tips [Redmine: 210279]
		- 20241028@Kos: Support Virtual Sports 6 [Redmine: 212446]
		- 20250225@Kos: Fix bug FLOAT rounding [#Redmine: 194970]
		- 20250313@Kos: Remove BA [RedmineID: #216882]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @TempAg TABLE (CustId INT PRIMARY KEY, Currency INT)

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
		SELECT ErrCode = 100,
			ErrMsg = N'Invalid Parameter.'

		RETURN
	END CATCH

	-- Get SportBetTypeMatrix
	DECLARE @SportBettype TABLE ( ProductID TINYINT, Bettype SMALLINT, EventType TINYINT, RefTable TINYINT)

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	IF @RefNo <> 0		-- Search by refno
	BEGIN
		INSERT INTO @SportBettype
		SELECT ProductID, BetType, EventType, RefTable
		FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest)
		WHERE ProductID NOT IN (2, 4, 7, 9, 11, 12, 13, 14, 15, 17, 19, 23, 24, 26, 30, 31, 33, 46, 47, 50, 52, 59, 65)
			AND BetType NOT IN (71, 72, 901, 902, 903, 904, 911, 912, 913, 914, 997, 999)
			AND BetType NOT BETWEEN 801 AND 899
	END
	ELSE IF ISNULL(@TxId, '') <> ''		-- Search by licensee TxId
	BEGIN
		INSERT INTO @SportBettype
		SELECT ProductID, BetType, EventType, RefTable
		FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest)
		WHERE ProductID IN (1, 3, 5, 8, 27, 28, 40, 60, 63, 66, 69, 71, 74, 77, 83)
			AND BetType NOT IN (901, 902, 903, 904, 997, 999)
			AND BetType NOT BETWEEN 801 AND 899
	END

	-- Get CustId in case of inputting Username
	IF @CustId = 0 AND @Username <> ''
	BEGIN
		SET @CustId = -1

		SELECT @CustId = custid
		FROM dbo.Customer AS c WITH (NOLOCK)
		WHERE EXISTS (SELECT 1 FROM @TempAg WHERE CustId = c.recommend)
			AND c.username = @Username

		IF @CustId = -1
		BEGIN
			DECLARE @Site VARCHAR(10)

			SELECT @Site = site
			FROM dbo.Customer WITH (NOLOCK)
			WHERE custid IN (SELECT TOP(1) CustId FROM @TempAg)

			SELECT @CustId = custid
			FROM dbo.Customer WITH (NOLOCK)
			WHERE username2 LIKE @Site + '$' + @Username
		END
	END

	IF @ViewSabaCoins = 1 AND @CustId <> 0
	BEGIN
		SELECT @CustId = custid
		FROM dbo.Customer WITH (NOLOCK)
		WHERE username2 = 'SabaCoins$' + CONVERT(VARCHAR(10), @CustId)
	END

	DECLARE @Data TABLE (
		TransId				BIGINT,
		RefNo				BIGINT,
		CustId				INT,
		Currency			SMALLINT,
		Recommend			INT,
		SportType			SMALLINT,
		BetType				SMALLINT,
		BetId				BIGINT,
		BetTeam				NVARCHAR(200),
		Hdp1				SMALLMONEY,
		Hdp2				SMALLMONEY,
		OddsType			TINYINT,
		Odds				MONEY,
		MOdds				MONEY,
		OddsSpread			MONEY,
		Stake				MONEY,
		Actual_Stake		MONEY,
		WinLost				MONEY,
		LicenseeWL			MONEY,
		PlayerComm			MONEY,
		Comm				MONEY,
		Status				NVARCHAR(10),
		SettlementStatus	TINYINT,
		TransDate			DATETIME,
		WinLostDate			SMALLDATETIME,
		LiveIndicator		BIT,
		LiveHomeScore		SMALLINT,
		LiveAwayScore		SMALLINT,
		Ip					VARCHAR(45),
		BetFrom				NVARCHAR(4),
		LeagueId			INT,
		LeagueGroupId		SMALLINT,
		MatchId				INT,
		MatchCode			NVARCHAR(1000),
		Race				NVARCHAR(50),
		EventDate			DATETIME,
		HomeId				INT,
		AwayId				INT,
		BetStatus			NVARCHAR(50),
		IsNeutral			BIT,
		Placing				NVARCHAR(20),
		ShowTime			NVARCHAR(50),
		BetCheck			NVARCHAR(2000),
		TransDesc			NVARCHAR(1000),
		BetdaqId			BIGINT,
		ExtraInfo			VARCHAR(1000),
		JackpotInfo			VARCHAR(50),
		OriginalStake		MONEY,
		OriginalBetType		SMALLINT,
		WalletType			TINYINT,
		RefCode				BIGINT,
		SiteId				VARCHAR(20),
		WhTicket			TINYINT
	)
	
	DECLARE @Detail TABLE (
		RefNo			BIGINT,
		Odds			MONEY,
		Stake			MONEY,
		Status			NVARCHAR(10),
		APositionTaking	SMALLMONEY,
		BetType			SMALLINT,
		BetTeam			NVARCHAR(10)
	)

	DECLARE
		@OriginalCustId	INT,
		@TransId		BIGINT,
		@WinLostDate	SMALLDATETIME,
		@Recommend		INT,
		@Currency		SMALLINT,
		@BetType		SMALLINT,
		@RefCode		BIGINT		= 0,
		@ProductId		TINYINT,
		@EventType		TINYINT,
		@RefTable		TINYINT,
		@Product		VARCHAR(30),
		@WhTicket		TINYINT		= 0,
		@BonusTransId	BIGINT		= 0,
		@MainCustId		INT			= 0

	DECLARE @SabaRewardTicket TABLE (TransId BIGINT, WhTicket TINYINT)

	SET @OriginalCustId = @CustId

	IF @CustId <> -1
	BEGIN
		IF @RefNo <> 0		-- Search by refno
		BEGIN
			IF @ExcludeBettrans = 0
			BEGIN
				-- Translog range
				IF @WhTicket = 0
				BEGIN
					SELECT TOP(1)
						@TransId = b.translogid,
						@CustId = b.custid,
						@WinLostDate = b.winlostdate,
						@Recommend = b.recommend,
						@Currency = b.currency,
						@BetType = b.gameID,
						@ProductId = s.ProductID,
						@EventType = s.EventType,
						@RefTable = s.RefTable,
						@WhTicket = 1		-- translog
					FROM dbo.translog AS b WITH (NOLOCK)
						INNER JOIN @SportBettype AS s ON b.gameID = s.bettype
					WHERE b.translogid = @RefNo
						AND s.RefTable = 3
						AND (b.custid = @CustId OR @CustId = 0)
						AND b.statusID IN (0, 1)
				END

				-- Bettrans range
				IF @WhTicket = 0
				BEGIN
					SELECT TOP(1)
						@TransId = b.transid,
						@CustId = b.custid,
						@WinLostDate = b.winlostdate,
						@Recommend = b.recommend,
						@Currency = b.currency,
						@BetType = b.bettype,
						@RefCode = b.RefCode,
						@ProductId = s.ProductID,
						@EventType = s.EventType,
						@RefTable = s.RefTable,
						@WhTicket = 2		-- bettrans
					FROM dbo.bettrans AS b WITH (NOLOCK)
						INNER JOIN @SportBettype AS s ON b.bettype = s.bettype
					WHERE (b.transid = @RefNo
							OR (b.refno = @RefNo AND s.RefTable = 3))
						AND (b.custid = @CustId OR @CustId = 0)
						AND b.winlostdate > @MoveBetsDay
				END
			END

			-- Bettrans14 range
			IF @WhTicket = 0
			BEGIN
				SELECT TOP(1)
					@TransId = b.transid,
					@CustId = b.custid,
					@WinLostDate = b.winlostdate,
					@Recommend = b.recommend,
					@Currency = b.currency,
					@BetType = b.bettype,
					@RefCode = b.RefCode,
					@ProductId = s.ProductID,
					@EventType = s.EventType,
					@RefTable = s.RefTable,
					@WhTicket = 3		-- bettrans14
				FROM dbo.bettrans14 AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON b.bettype = s.bettype
				WHERE (b.transid = @RefNo
						OR (b.refno = @RefNo AND s.RefTable = 3))
					AND (b.custid = @CustId OR @CustId = 0)
					AND b.winlostdate BETWEEN @BalanceUpDay AND @MoveBetsDay
			END

			-- Bettrans_bk range
			IF @WhTicket = 0
			BEGIN
				IF @CustId = 0
				BEGIN
					SELECT TOP(1)
						@TransId = b.transid,
						@CustId = b.custid,
						@WinLostDate = b.winlostdate,
						@Recommend = b.recommend,
						@Currency = b.currency,
						@BetType = b.bettype,
						@RefCode = b.RefCode,
						@ProductId = s.ProductID,
						@EventType = s.EventType,
						@RefTable = s.RefTable,
						@WhTicket = 4		-- bettrans_bk
					FROM bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK)
						INNER JOIN @SportBettype AS s ON b.bettype = s.bettype
					WHERE b.transid = @RefNo
				END
				ELSE
				BEGIN
					SELECT TOP(1)
						@TransId = b.transid,
						@CustId = b.custid,
						@WinLostDate = b.winlostdate,
						@Recommend = b.recommend,
						@Currency = b.currency,
						@BetType = b.bettype,
						@RefCode = b.RefCode,
						@ProductId = s.ProductID,
						@EventType = s.EventType,
						@RefTable = s.RefTable,
						@WhTicket = 4		-- bettrans_bk
					FROM bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK, INDEX = IX_transid)
						INNER JOIN @SportBettype AS s ON b.bettype = s.bettype
					WHERE b.custid = @CustId AND b.transid = @RefNo

					IF @WhTicket = 0
					BEGIN
						SELECT TOP(1)
							@TransId = b.transid,
							@CustId = b.custid,
							@WinLostDate = b.winlostdate,
							@Recommend = b.recommend,
							@Currency = b.currency,
							@BetType = b.bettype,
							@RefCode = b.RefCode,
							@ProductId = s.ProductID,
							@EventType = s.EventType,
							@RefTable = s.RefTable,
							@WhTicket = 4		-- bettrans_bk
						FROM bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK, INDEX = IX_custid)
							INNER JOIN @SportBettype AS s ON b.bettype = s.bettype
						WHERE b.custid = @CustId
							AND b.refno = @RefNo
							AND s.RefTable = 3
					END
				END
			END
		END
		ELSE IF ISNULL(@TxId, '') <> '' AND @CustId <> 0
		BEGIN
			IF @ExcludeBettrans = 0
			BEGIN
				-- Bettrans range
				IF @WhTicket = 0
				BEGIN
					SELECT TOP(1)
						@TransId = b.transid,
						@CustId = b.custid,
						@WinLostDate = b.winlostdate,
						@Recommend = b.recommend,
						@Currency = b.currency,
						@BetType = b.bettype,
						@RefCode = b.RefCode,
						@ProductId = s.ProductID,
						@EventType = s.EventType,
						@RefTable = s.RefTable,
						@WhTicket = 2		-- bettrans
					FROM dbo.bettrans AS b WITH (NOLOCK)
						INNER JOIN @TempAg AS ta ON ta.CustId = b.recommend
						INNER JOIN @SportBettype AS s ON b.bettype = s.bettype
					WHERE b.custid = @CustId
						AND b.winlostdate > @MoveBetsDay
						AND @TxId = CASE
										WHEN b.ExtraInfo LIKE '%p83%'
											THEN ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p83/@lt)[1]','VARCHAR(100)'), 0)
										WHEN b.ExtraInfo LIKE '%p77%'
											THEN ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p77/@lt)[1]','VARCHAR(100)'), 0)
										WHEN b.ExtraInfo LIKE '%p74%'
											THEN ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p74/@lt)[1]','VARCHAR(100)'), 0)
										WHEN b.ExtraInfo LIKE '%p71%'
											THEN ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p71/@lt)[1]','VARCHAR(100)'), 0)
										WHEN b.ExtraInfo LIKE '%p69%'
											THEN ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p69/@lt)[1]','VARCHAR(100)'), 0)
										WHEN b.ExtraInfo LIKE '%p63%'
											THEN ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p63/@lt)[1]','VARCHAR(100)'), 0)
										WHEN b.ExtraInfo LIKE '%p40%'
											THEN ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p40/@lt)[1]','VARCHAR(100)'), 0)
										WHEN b.ExtraInfo LIKE '%p28%'
											THEN ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p28/@lt)[1]','VARCHAR(100)'), 0)
										WHEN b.ExtraInfo LIKE '%p27%'
											THEN ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p27/@lt)[1]','VARCHAR(100)'), 0)
										WHEN b.ExtraInfo LIKE '%p8%'
											THEN ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p8/@lt)[1]','VARCHAR(100)'), 0)
										WHEN b.ExtraInfo LIKE '%p5%'
											THEN ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p5/@lt)[1]','VARCHAR(100)'), 0)
										WHEN b.ExtraInfo LIKE '%p3%'
											THEN ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p3/@lt)[1]','VARCHAR(100)'), 0)
										WHEN b.ExtraInfo LIKE '%p1%'
											THEN ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p1/@lt)[1]','VARCHAR(100)'), 0)
										ELSE ''
									END
				END
			END

			-- Bettrans14 range
			IF @WhTicket = 0
			BEGIN
				SELECT TOP(1)
					@TransId = b.transid,
					@CustId = b.custid,
					@WinLostDate = b.winlostdate,
					@Recommend = b.recommend,
					@Currency = b.currency,
					@BetType = b.bettype,
					@RefCode = b.RefCode,
					@ProductId = s.ProductID,
					@EventType = s.EventType,
					@RefTable = s.RefTable,
					@WhTicket = 3		-- bettrans14
				FROM dbo.bettrans14 AS b WITH (NOLOCK)
					INNER JOIN @TempAg AS ta ON ta.CustId = b.recommend
					INNER JOIN @SportBettype AS s ON b.bettype = s.bettype
				WHERE b.custid = @CustId
					AND b.winlostdate BETWEEN @BalanceUpDay AND @MoveBetsDay
					AND @TxId = CASE
									WHEN b.ExtraInfo LIKE '%p83%'
										THEN ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p83/@lt)[1]','VARCHAR(100)'), 0)
									WHEN b.ExtraInfo LIKE '%p77%'
										THEN ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p77/@lt)[1]','VARCHAR(100)'), 0)
									WHEN b.ExtraInfo LIKE '%p74%'
										THEN ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p74/@lt)[1]','VARCHAR(100)'), 0)
									WHEN b.ExtraInfo LIKE '%p71%'
											THEN ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p71/@lt)[1]','VARCHAR(100)'), 0)
									WHEN b.ExtraInfo LIKE '%p69%'
										THEN ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p69/@lt)[1]','VARCHAR(100)'), 0)
									WHEN b.ExtraInfo LIKE '%p63%'
										THEN ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p63/@lt)[1]','VARCHAR(100)'), 0)
									WHEN b.ExtraInfo LIKE '%p40%'
										THEN ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p40/@lt)[1]','VARCHAR(100)'), 0)
									WHEN b.ExtraInfo LIKE '%p28%'
										THEN ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p28/@lt)[1]','VARCHAR(100)'), 0)
									WHEN b.ExtraInfo LIKE '%p27%'
										THEN ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p27/@lt)[1]','VARCHAR(100)'), 0)
									WHEN b.ExtraInfo LIKE '%p8%'
										THEN ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p8/@lt)[1]','VARCHAR(100)'), 0)
									WHEN b.ExtraInfo LIKE '%p5%'
										THEN ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p5/@lt)[1]','VARCHAR(100)'), 0)
									WHEN b.ExtraInfo LIKE '%p3%'
										THEN ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p3/@lt)[1]','VARCHAR(100)'), 0)
									WHEN b.ExtraInfo LIKE '%p1%'
										THEN ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p1/@lt)[1]','VARCHAR(100)'), 0)
									ELSE ''
								END
			END
		END

		IF @WhTicket > 0
		BEGIN
			IF @ViewSabaCoins = 0
				AND NOT EXISTS (SELECT 1 FROM @TempAg WHERE CustId = @Recommend AND Currency = @Currency)
			BEGIN
				SET @WhTicket = 0
			END
			ELSE IF @ViewSabaCoins = 1
			BEGIN
				SELECT @MainCustId = CASE
										WHEN CHARINDEX('SabaCoins$', username2) > 0
											THEN CAST(SUBSTRING(username2, CHARINDEX('SabaCoins$', username2) + LEN('SabaCoins$'), LEN(username2)) AS INT)
										ELSE 0
									END
				FROM dbo.Customer WITH (NOLOCK)
				WHERE custid = @CustId

				IF NOT EXISTS ( SELECT 1
								FROM @TempAg AS ta
									INNER JOIN dbo.Customer AS c WITH (NOLOCK) ON ta.CustId = c.recommend AND ta.Currency = c.currency
								WHERE c.custid = @MainCustId)
				BEGIN
					SET @WhTicket = 0
				END
			END
		END
	END

	SET @Product = CASE
						WHEN @ProductId = 6 THEN 'OneRNG'		-- RNG Casino
						WHEN @ProductId = 8 THEN 'Keno'
						WHEN @ProductId = 21 THEN 'AllBet'
						WHEN @ProductId = 22 THEN 'VB'			-- Macau Games
						WHEN @ProductId = 28 THEN 'Lottery'
						WHEN @ProductId = 32 THEN 'PP'			-- Pragmatic Play Casino
						WHEN @ProductId = 34 THEN 'CC'			-- Card Club
						WHEN @ProductId = 36 THEN 'SG'			-- Spadegaming
						WHEN @ProductId = 37 THEN 'SPR'			-- Saba Promotion
						WHEN @ProductId = 38 THEN 'VRG'			-- Virtual Games
						WHEN @ProductId = 39 THEN 'SAG'			-- SA Gaming
						WHEN @ProductId = 40 THEN 'TG'			-- Table Games
						WHEN @ProductId = 42 THEN 'SBC'			-- Saba.club
						WHEN @ProductId = 43 THEN 'I4D'			-- Indo 4D
						WHEN @ProductId = 45 THEN 'SXG'			-- Sexy Gaming
						WHEN @ProductId = 49 THEN 'VS3'			-- Virtual Sports 3 (Old)
						WHEN @ProductId = 51 THEN 'WM'			-- WM Live Casino
						WHEN @ProductId = 55 THEN 'PGS'			-- PG Soft
						WHEN @ProductId = 56 THEN 'JK'			-- Joker
						WHEN @ProductId = 57 THEN 'BG'			-- Big Gaming
						WHEN @ProductId = 60 THEN 'MXG'			-- MaxGame
						WHEN @ProductId = 61 THEN 'HB'			-- Habanero
						WHEN @ProductId = 62 THEN 'CG'			-- CG
						WHEN @ProductId = 63 THEN 'SLT'			-- SLT
						WHEN @ProductId = 66 THEN 'VGA'			-- Vgaming
						WHEN @ProductId = 67 THEN 'AP'			-- AdvantPlay
						WHEN @ProductId = 68 THEN 'APM'			-- AdvantPlay Mini
						WHEN @ProductId = 69 THEN 'BTC'			-- Bitcoin
						WHEN @ProductId = 70 THEN 'FGGL'		-- FGG
						WHEN @ProductId = 72 THEN 'SEA'			-- SEAL Entertainment
						WHEN @ProductId = 73 THEN 'MGRNG'		-- MG-RNG
						WHEN @ProductId = 74 THEN 'TIP'			-- Player Tips
						WHEN @ProductId = 75 THEN 'JIG'			-- Jili
						WHEN @ProductID = 76 THEN 'YB'			-- YeeBet
						WHEN @ProductID = 77 THEN 'LG'			-- Virtual Sports 3
						WHEN @EventType = 0 AND @ProductId = 1 THEN 'Parlay'		-- Sportsbook Parlay
						WHEN @EventType = 0 AND @ProductId = 3 THEN 'H5LG'			-- Happy 5 Linked Games (Number Game)
						WHEN @EventType = 0 AND @ProductId = 27 THEN 'ParlayVS2'	-- Betradar Virtual Sports Parlay
						WHEN @EventType = 1 AND @ProductId = 1 THEN 'SB'			-- Sportsbook
						WHEN @EventType = 1 AND @ProductId = 3 THEN 'NG'			-- Number Game
						WHEN @EventType = 1 AND @ProductId = 5 THEN 'VS'			-- Virtual Sports Sportsbook
						WHEN @EventType = 1 AND @ProductId = 27 THEN 'VS2'			-- Betradar Virtual Sports
						WHEN @EventType = 2 AND @ProductId = 1 THEN 'Outright'
						ELSE 'Unknown'
					END

	-- Get related Bonus/Cash ticket
	IF @RefCode <> 0 AND @Product = 'SB'
	BEGIN
		IF @WhTicket = 2
		BEGIN
			SELECT TOP(1) @BonusTransId = b.transid
			FROM dbo.bettrans AS b WITH (NOLOCK)
			WHERE b.custid = @CustId
				AND b.winlostdate = @WinLostDate
				AND b.RefCode = @RefCode
				AND b.transid <> @TransId
		END
		ELSE IF @WhTicket = 3
		BEGIN
			SELECT TOP(1) @BonusTransId = b.transid
			FROM dbo.bettrans14 AS b WITH (NOLOCK)
			WHERE b.custid = @CustId
				AND b.winlostdate = @WinLostDate
				AND b.RefCode = @RefCode
				AND b.transid <> @TransId
		END
		ELSE IF @WhTicket = 4
		BEGIN
			SELECT TOP(1) @BonusTransId = b.transid
			FROM bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK, INDEX = IX_custid)
			WHERE b.custid = @CustId
				AND b.winlostdate = @WinLostDate
				AND b.RefCode = @RefCode
				AND b.transid <> @TransId
		END
	END

	-- Get related Saba Reward tickets
	IF @Product = 'SB'
	BEGIN
		IF @WhTicket = 2
		BEGIN
			INSERT INTO @SabaRewardTicket (
				TransId,
				WhTicket)
			SELECT
				transid,
				2 AS WhTicket
			FROM dbo.bettrans AS b WITH (NOLOCK)
			WHERE b.custid = @CustId
				AND b.refno = @TransId
				AND b.bettype = 17007
		END
		ELSE IF @WhTicket = 3
		BEGIN
			INSERT INTO @SabaRewardTicket (
				TransId,
				WhTicket)
			SELECT
				transid,
				2 AS WhTicket
			FROM dbo.bettrans AS b WITH (NOLOCK)
			WHERE b.custid = @CustId
				AND b.refno = @TransId
				AND b.bettype = 17007
				AND b.winlostdate > @MoveBetsDay

			UNION

			SELECT
				transid,
				3 AS WhTicket
			FROM dbo.bettrans14 AS b WITH (NOLOCK)
			WHERE b.custid = @CustId
				AND b.refno = @TransId
				AND b.bettype = 17007
				AND b.winlostdate BETWEEN @BalanceUpDay AND @MoveBetsDay
		END
	END

	DECLARE @Yesterday SMALLDATETIME = DATEADD(DAY, DATEDIFF(DAY, 1, CURRENT_TIMESTAMP), 0)

	IF @WhTicket = 1	-- translog
	BEGIN
		INSERT INTO @Data
		SELECT
			b.translogid AS TransId,
			b.translogid AS RefNo,
			b.custid,
			b.currency,
			b.recommend,
			b.productID AS SportType,
			b.gameID AS BetType,
			0 AS BetId,
			'' AS BetTeam,
			0 AS Hdp1,
			0 AS Hdp2,
			0 AS OddsType,
			b.odds,
			0 AS MOdds,
			0 AS OddsSpread,
			b.stake,
			b.actual_stake,
			0 AS WinLost,
			0 AS LicenseeWL,
			0 AS PlayerComm,
			0 AS Comm,
			b.status,
			0 AS SettlementStatus,
			b.transdate,
			b.winlostdate,
			0 AS LiveIndicator,
			0 AS LiveHomeScore,
			0 AS LiveAwayScore,
			b.ip,
			b.betfrom,
			0 AS LeagueId,
			0 AS LeagueGroupId,
			0 AS MatchId,
			'' AS MatchCode,
			'' AS Race,
			b.winlostdate AS EventDate,
			0 AS HomeId,
			0 AS AwayId,
			'' AS BetStatus,
			0 AS IsNeutral,
			'' AS Placing,
			'' AS ShowTime,
			CASE
				WHEN @Product IN ('Keno') THEN ISNULL(b.custom2, '')
				WHEN @Product IN ('VRG', 'SLT') THEN b.TranId3rd
				WHEN @Product IN ('H5LG') THEN b.Gameid3rd
				WHEN @Product IN ('VS3') THEN ISNULL(b.custom1, '')
				ELSE ''
			END AS BetCheck,
			ISNULL(b.transdesc, '') AS TransDesc,
			-1 AS BetdaqId,
			'' AS ExtraInfo,
			'' AS JackpotInfo,
			0 AS OriginalStake,
			0 AS OriginalBetType,
			0 AS WalletType,
			0 AS RefCode,
			ISNULL(b.SiteId, '') AS SiteId,
			1 AS WhTicket
		FROM dbo.translog AS b WITH (NOLOCK)
		WHERE b.translogid = @TransId
	END
	
	IF @WhTicket = 2	-- Bettrans
		OR EXISTS (SELECT 1 FROM @SabaRewardTicket WHERE WhTicket = 2)
	BEGIN
		IF @WhTicket = 2
		BEGIN
			DECLARE @TmpData TABLE (
				Odds			MONEY,
				Stake			MONEY,
				Actual_Stake	MONEY,
				Status			NVARCHAR(10),
				WinLost			MONEY,
				LicenseeWL		MONEY,
				PlayerComm		MONEY,
				Comm			MONEY,
				OddsSpread		MONEY
			)

			IF @RefTable IN (1, 2) AND @WinLostDate >= @Yesterday
			BEGIN
				-- bettransRnG
				IF @RefTable = 1
				BEGIN
					INSERT INTO @TmpData
					SELECT
						CASE
							WHEN @Product IN ('OneRNG', 'PP', 'SBC', 'VGA', 'SG') THEN ISNULL(AVG(CASE WHEN statusID IN (111, 112, 113) THEN ContributionRate END), 0)
							ELSE 0
						END AS Odds,
						SUM(stake) AS Stake,
						SUM(actual_stake) AS Actual_Stake,
						CASE
							WHEN SUM(winlost - actual_stake) > 0 THEN 'Won'
							WHEN SUM(winlost - actual_stake) < 0 THEN 'Lose'
							ELSE 'Draw'
						END AS Status,
						SUM(winlost - actual_stake) AS WinLost,
						- SUM(winlost - actual_stake) AS LicenseeWL,
						SUM(playercomm) AS Commission,
						SUM(comm) AS Comm,
						CASE
							WHEN @Product IN ('OneRNG', 'PP', 'SBC', 'VGA', 'SG') THEN ISNULL(SUM(BetStake), 0)
							ELSE 0
						END AS OddsSpread
					FROM dbo.bettransRnG WITH (NOLOCK)
					WHERE RefNo = @TransId AND statusID NOT IN (0, 1)
					GROUP BY RefNo

					INSERT INTO @TmpData
					SELECT
						0 AS Odds,
						SUM(stake) AS Stake,
						SUM(actual_stake) AS Actual_Stake,
						'Running' AS Status,
						0 AS WinLost,
						0 AS LicenseeWL,
						0 AS PlayerComm,
						0 AS Comm,
						0 AS OddsSpread
					FROM dbo.bettransRnG WITH (NOLOCK)
					WHERE RefNo = @TransId AND statusID IN (0, 1)
					GROUP BY RefNo
				END

				-- bettransLC
				IF @RefTable = 2
				BEGIN
					INSERT INTO @TmpData
					SELECT
						0 AS Odds,
						SUM(stake) AS Stake,
						SUM(actual_stake) AS Actual_Stake,
						CASE
							WHEN SUM(winlost - actual_stake) > 0 THEN 'Won'
							WHEN SUM(winlost - actual_stake) < 0 THEN 'Lose'
							ELSE 'Draw'
						END AS Status,
						SUM(winlost - actual_stake) AS WinLost,
						- SUM(winlost - actual_stake) AS LicenseeWL,
						SUM(playercomm) AS Commission,
						SUM(comm) AS Comm,
						0 AS OddsSpread
					FROM dbo.bettransLC WITH (NOLOCK)
					WHERE RefNo = @TransId AND statusID NOT IN (0, 1)
					GROUP BY RefNo

					INSERT INTO @TmpData
					SELECT
						0 AS Odds,
						SUM(stake) AS Stake,
						SUM(actual_stake) AS Actual_Stake,
						'Running' AS Status,
						0 AS WinLost,
						0 AS LicenseeWL,
						0 AS PlayerComm,
						0 AS Comm,
						0 AS OddsSpread
					FROM dbo.bettransLC WITH (NOLOCK)
					WHERE RefNo = @TransId AND statusID IN (0, 1)
					GROUP BY RefNo
				END
			END
		END

		INSERT INTO @Data
		SELECT
			CASE
				WHEN @Product = 'Parlay' AND b.bettype = 29 AND ISNULL(b.betid, 0) > 0 THEN b.betid
				ELSE b.transid
			END AS TransId,
			b.refno,
			b.custid,
			b.currency,
			b.recommend,
			CASE
				WHEN b.transid NOT IN (@TransId, @BonusTransId) THEN b.matchid		-- 17007
				WHEN @Product IN ('Keno', 'Lottery', 'VB', 'PP', 'OneRNG', 'CC', 'SG', 'Allbet', 'SPR', 'VRG', 'TG', 'SBC', 'I4D', 'SXG', 
					'SAG', 'PGS', 'JK', 'H5LG', 'SLT', 'HB', 'WM', 'BG', 'VGA', 'CG', 'AP', 'APM', 'VS3', 'FGGL', 'MXG', 'TIP', 'JIG', 'YB', 'MGRNG', 'SEA') THEN b.matchid
				WHEN @Product IN ('Outright') THEN l.sporttype
				WHEN @EventType = 1 THEN m.sporttype
				WHEN @EventType = 3 THEN vr.SportType
				WHEN @EventType = 5 THEN m3rd.SportType
				WHEN @RefTable IN (1, 2) THEN b.matchid
				ELSE b.matchid
			END AS SportType,
			b.bettype,
			ISNULL(b.betid, 0) AS BetId,
			b.betteam,
			b.hdp1,
			b.hdp2,
			b.oddstype,
			CASE
				WHEN @Product IN ('VB', 'PP', 'OneRNG', 'Allbet', 'SBC', 'VGA', 'SG') AND x.Odds IS NOT NULL THEN x.Odds
				ELSE b.odds
			END AS Odds,
			b.modds,
			CASE
				WHEN @Product IN ('PP', 'SBC', 'VGA', 'SG') AND x.OddsSpread IS NOT NULL THEN x.OddsSpread
				ELSE ISNULL(b.oddsspread, 0)
			END AS OddsSpread,
			CASE
				WHEN @RefTable IN (1, 2) AND x.Stake IS NOT NULL THEN x.Stake
				ELSE b.stake
			END AS Stake,
			CASE
				WHEN @RefTable IN (1, 2) AND x.Actual_Stake IS NOT NULL THEN x.Actual_Stake
				ELSE b.actual_stake
			END AS Actual_Stake,
			CASE
				WHEN @RefTable IN (1, 2) AND x.WinLost IS NOT NULL THEN x.WinLost
				ELSE b.winlost - b.actual_stake
			END AS WinLost,
			CASE
				WHEN @RefTable IN (1, 2) AND x.LicenseeWL IS NOT NULL THEN x.LicenseeWL
				ELSE - (b.winlost - b.actual_stake)
			END AS LicenseeWL,
			CASE
				WHEN @RefTable IN (1, 2) AND x.PlayerComm IS NOT NULL THEN x.PlayerComm
				ELSE b.PlayerComm
			END AS PlayerComm,
			CASE
				WHEN @RefTable IN (1, 2) AND x.Comm IS NOT NULL THEN x.Comm
				ELSE b.Comm
			END AS Comm,
			CASE
				WHEN @RefTable IN (1, 2) AND x.status IS NOT NULL THEN x.status
				WHEN @Product IN ('SB')
					AND b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
				WHEN @Product = 'Parlay' AND b.status = 'running' THEN
						CASE
							WHEN EXISTS (SELECT 1 FROM dbo.bettransm AS bm WITH (NOLOCK)
										WHERE bm.custid = b.custid
											AND bm.refno = b.refno
											AND (bm.status = 'waiting'
												OR (bm.status = 'running' AND ISNULL(bm.SecAcceptFlag, 0) = 1 AND ISNULL(bm.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP)))
								THEN 'Waiting'
							ELSE b.status
						END
				WHEN @Product = 'TG' AND b.status = 'Won' AND b.modds = 0.25 THEN 'Half Won'
				WHEN @Product = 'TG' AND b.status = 'Lose' AND b.modds = -0.25 THEN 'Half Lose'
				ELSE b.status
			END AS Status,
			CASE
				WHEN @Product IN ('SB') THEN ISNULL(m.SettlementStatus, 0)
				ELSE 0
			END AS SettlementStatus,
			b.transdate,
			b.winlostdate,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			b.ip,
			b.betfrom,
			CASE
				WHEN @EventType = 1 THEN m.leagueid
				WHEN @EventType = 5 THEN m3rd.League3rdId
				WHEN @Product IN ('Outright') THEN o.leagueid
				WHEN @EventType = 3 THEN vr.LeagueID
				ELSE 0
			END AS LeagueId,
			CASE
				WHEN @Product IN ('SB') THEN le.LeagueGroupID
				ELSE 0
			END AS LeagueGroupId,
			CASE
				WHEN @Product = 'TIP' THEN ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p74/@m)[1]','INT'), 0)
				ELSE b.matchid
			END AS MatchId,
			CASE
				WHEN @EventType = 1 THEN m.matchcode
				WHEN @Product IN ('Outright') THEN o.matchcode
				ELSE ''
			END AS MatchCode,
			CASE
				WHEN @Product IN ('Outright') THEN o.groupmatch
				ELSE ''
			END AS Race,
			CASE
				WHEN @Product IN ('SB') THEN m.GlobalShowTime
				WHEN @Product IN ('BTC') THEN m3rd.EndTime
				ELSE b.WinLostDate
			END AS EventDate,
			CASE
				WHEN @EventType = 1 THEN m.homeid
				WHEN @EventType = 5 THEN m3rd.HomeId
				WHEN @Product IN ('Outright') THEN o.teamid
				ELSE 0
			END AS HomeId,
			CASE
				WHEN @EventType = 1 THEN m.awayid
				WHEN @EventType = 5 THEN m3rd.AwayId
				ELSE 0
			END AS AwayId,
			CASE
				WHEN @EventType = 1 THEN m.betstatus
				ELSE ''
			END AS BetStatus,
			CASE
				WHEN @EventType = 1 THEN ISNULL(m.IsNeutral, 0)
				ELSE 0
			END AS IsNeutral,
			'' AS Placing,
			CASE
				WHEN @Product IN ('VS') THEN CONVERT(NVARCHAR(50), m.kickofftime)
				WHEN @EventType = 5 THEN CONVERT(NVARCHAR(50), m3rd.StartTime)
				ELSE ''
			END AS ShowTime,
			CASE
				WHEN @Product IN ('SB', 'VRG', 'SLT', 'H5LG') THEN ISNULL(b.betcheck, '')
				WHEN @Product IN ('Keno') THEN ISNULL(b.ComStatus, '')
				WHEN @EventType = 0 AND @RefTable = 0 THEN ISNULL(b.betcheck, '')
				ELSE ''
			END AS BetCheck,
			CASE
				WHEN @Product IN ('Keno', 'Lottery', 'OneRNG', 'CC', 'SG', 'VB', 
					'PP', 'VRG', 'TG', 'I4D', 'PGS', 'JK', 'H5LG', 'SLT', 'HB', 'CG', 'AP', 'APM', 'SEA') THEN ISNULL(b.transdesc, '')
				WHEN @EventType IN (1, 3) THEN ISNULL(b.transdesc, '')
				ELSE ''
			END AS TransDesc,
			CASE
				WHEN @Product IN ('SB') THEN ISNULL(b.betdaqid, -1)
				ELSE -1
			END AS BetdaqId,
			ISNULL(b.ExtraInfo, '') AS ExtraInfo,
			'' AS JackpotInfo,
			0 AS OriginalStake,
			CASE
				WHEN @Product IN ('SB') AND b.stake <> 0 THEN -1
				ELSE 0
			END AS OriginalBetType,
			CASE
				WHEN @Product IN ('SB') THEN ISNULL(b.WalletType, 0)
				ELSE 0
			END AS WalletType,
			CASE
				WHEN @Product IN ('SB') AND b.stake <> 0 THEN ISNULL(b.RefCode, 0)
				ELSE 0
			END AS RefCode,
			CASE
				WHEN @Product IN ('H5LG', 'SLT', 'VRG') THEN CONVERT(VARCHAR(20), b.BetdaqId)
				ELSE ''
			END AS SiteId,
			2 AS WhTicket
		FROM dbo.bettrans AS b WITH (NOLOCK)
			LEFT JOIN @TmpData AS x ON @RefTable IN (1, 2) AND @Winlostdate >= @Yesterday
			LEFT JOIN dbo.match AS m WITH (NOLOCK) ON @EventType = 1 AND b.matchid = m.matchid
			LEFT JOIN dbo.League AS le WITH (NOLOCK) ON @Product IN ('SB') AND le.leagueid = m.leagueid
			LEFT JOIN dbo.Match3rd AS m3rd WITH (NOLOCK) ON @EventType = 5 AND m3rd.Match3rdId = b.matchid
			LEFT JOIN dbo.outright AS o WITH (NOLOCK) ON @Product IN ('Outright') AND b.matchid = o.orid
			LEFT JOIN dbo.League AS l WITH (NOLOCK) ON @Product IN ('Outright') AND o.leagueID = l.leagueID
			LEFT JOIN dbo.VSRaceInfo AS vr WITH (NOLOCK) ON @EventType = 3 AND vr.EventID = b.matchid
		WHERE b.transid IN (@TransId, @BonusTransId)
			OR b.transid IN (SELECT TransId FROM @SabaRewardTicket WHERE WhTicket = 2)
	END
	
	IF @WhTicket = 3		-- Bettrans14 range
	BEGIN
		INSERT INTO @Data
		SELECT
			CASE
				WHEN @Product = 'Parlay' AND b.bettype = 29 AND ISNULL(b.betid, 0) > 0 THEN b.betid
				ELSE b.transid
			END AS TransId,
			b.refno,
			b.custid,
			b.currency,
			b.recommend,
			CASE
				WHEN b.transid NOT IN (@TransId, @BonusTransId) THEN b.matchid		-- 17007
				WHEN @Product IN ('Keno', 'Lottery', 'VB', 'PP', 'OneRNG', 'CC', 'SG', 'Allbet', 'SPR', 'VRG', 'TG', 'SBC', 
					'I4D', 'SXG', 'SAG', 'PGS', 'JK', 'H5LG', 'SLT', 'HB', 'WM', 'BG', 'VGA', 'CG', 'AP', 'APM', 'VS3', 'FGGL', 'MXG', 'TIP', 'JIG', 'YB', 'MGRNG', 'SEA') THEN b.matchid
				WHEN @Product IN ('Outright') THEN l.sporttype
				WHEN @EventType = 1 THEN m.sporttype
				WHEN @EventType = 3 THEN vr.SportType
				WHEN @EventType = 5 THEN m3rd.SportType
				WHEN @RefTable IN (1, 2) THEN b.matchid
				ELSE b.matchid
			END AS SportType,
			b.bettype,
			ISNULL(b.betid, 0) AS BetId,
			b.betteam,
			b.hdp1,
			b.hdp2,
			b.oddstype,
			b.odds,
			b.modds,
			ISNULL(b.oddsspread, 0) AS OddsSpread,
			b.stake,
			b.actual_stake,
			(b.winlost - b.actual_stake) AS WinLost,
			- (b.winlost - b.actual_stake) AS LicenseeWL,
			b.playercomm,
			b.comm,
			CASE
				WHEN @Product = 'TG' AND b.status = 'Won' AND b.modds = 0.25 THEN 'Half Won'
				WHEN @Product = 'TG' AND b.status = 'Lose' AND b.modds = -0.25 THEN 'Half Lose'
				ELSE b.status
			END AS Status,
			0 AS SettlementStatus,
			b.transdate,
			b.winlostdate,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			b.ip,
			b.betfrom,
			CASE
				WHEN @EventType = 1 THEN m.leagueid
				WHEN @EventType = 5 THEN m3rd.League3rdId
				WHEN @Product IN ('Outright') THEN o.leagueid
				WHEN @EventType = 3 THEN vr.LeagueID
				ELSE 0
			END AS LeagueId,
			CASE
				WHEN @Product IN ('SB') THEN le.LeagueGroupID
				ELSE 0
			END AS LeagueGroupId,
			CASE
				WHEN @Product = 'TIP' THEN ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p74/@m)[1]','INT'), 0)
				ELSE b.matchid
			END AS MatchId,
			CASE
				WHEN @EventType = 1 THEN m.matchcode
				WHEN @Product IN ('Outright') THEN o.matchcode
				ELSE ''
			END AS MatchCode,
			CASE
				WHEN @Product IN ('Outright') THEN o.groupmatch
				ELSE ''
			END AS Race,
			CASE
				WHEN @Product IN ('SB') THEN m.GlobalShowTime
				WHEN @Product IN ('BTC') THEN m3rd.EndTime
				ELSE b.WinLostDate
			END AS EventDate,
			CASE
				WHEN @EventType = 1 THEN m.homeid
				WHEN @EventType = 5 THEN m3rd.HomeId
				WHEN @Product IN ('Outright') THEN o.teamid
				ELSE 0
			END AS HomeId,
			CASE
				WHEN @EventType = 1 THEN m.awayid
				WHEN @EventType = 5 THEN m3rd.AwayId
				ELSE 0
			END AS AwayId,
			CASE
				WHEN @EventType = 1THEN m.betstatus
				ELSE ''
			END AS BetStatus,
			CASE
				WHEN @EventType = 1 THEN ISNULL(m.IsNeutral, 0)
				ELSE 0
			END AS IsNeutral,
			'' AS Placing,
			CASE
				WHEN @Product IN ('VS') THEN CONVERT(NVARCHAR(50), m.kickofftime)
				WHEN @EventType = 5 THEN CONVERT(NVARCHAR(50), m3rd.StartTime)
				ELSE ''
			END AS ShowTime,
			CASE
				WHEN @Product IN ('SB', 'VRG', 'SLT', 'H5LG') THEN ISNULL(b.betcheck, '')
				WHEN @Product IN ('Keno') THEN ISNULL(b.ComStatus, '')
				WHEN @EventType = 0 AND @RefTable = 0 THEN ISNULL(b.betcheck, '')
				ELSE ''
			END AS BetCheck,
			CASE
				WHEN @Product IN ('Keno', 'Lottery', 'OneRNG', 'CC', 'SG', 'VB', 
					'PP', 'VRG', 'TG', 'I4D', 'PGS', 'JK', 'H5LG', 'SLT', 'HB', 'CG', 'AP', 'APM', 'SEA') THEN ISNULL(b.transdesc, '')
				WHEN @EventType IN (1, 3) THEN ISNULL(b.transdesc, '')
				ELSE ''
			END AS TransDesc,
			CASE
				WHEN @Product IN ('SB') THEN ISNULL(b.betdaqid, -1)
				ELSE -1
			END AS BetdaqId,
			ISNULL(b.ExtraInfo, '') AS ExtraInfo,
			'' AS JackpotInfo,
			0 AS OriginalStake,
			CASE
				WHEN @Product IN ('SB') AND b.stake <> 0 THEN -1
				ELSE 0
			END AS OriginalBetType,
			CASE
				WHEN @Product IN ('SB') THEN ISNULL(b.WalletType, 0)
				ELSE 0
			END AS WalletType,
			CASE
				WHEN @Product IN ('SB') AND b.stake <> 0 THEN ISNULL(b.RefCode, 0)
				ELSE 0
			END AS RefCode,
			CASE
				WHEN @Product IN ('H5LG', 'SLT', 'VRG') THEN CONVERT(VARCHAR(20), b.BetdaqId)
				ELSE ''
			END AS SiteId,
			3 AS WhTicket
		FROM dbo.bettrans14 AS b WITH (NOLOCK)
			LEFT JOIN dbo.match14 AS m WITH (NOLOCK) ON @EventType = 1 AND b.matchid = m.matchid
			LEFT JOIN dbo.League AS le WITH (NOLOCK) ON @Product IN ('SB') AND le.leagueid = m.leagueid
			LEFT JOIN dbo.Match3rd14 AS m3rd WITH (NOLOCK) ON @EventType = 5 AND m3rd.Match3rdId = b.matchid
			LEFT JOIN dbo.outright14 AS o WITH (NOLOCK) ON @Product IN ('Outright') AND b.matchid = o.orid
			LEFT JOIN dbo.League AS l WITH (NOLOCK) ON @Product IN ('Outright') AND o.leagueID = l.leagueID
			LEFT JOIN dbo.VSRaceInfo14 AS vr WITH (NOLOCK) ON @EventType = 3 AND vr.EventID = b.matchid
		WHERE b.transid IN (@TransId, @BonusTransId)
			OR b.transid IN (SELECT TransId FROM @SabaRewardTicket WHERE WhTicket = 3)
	END
	
	IF @WhTicket = 4		-- Bettrans_bk range
	BEGIN
		INSERT INTO @Data
		SELECT
			CASE
				WHEN @Product = 'Parlay' AND b.bettype = 29 AND ISNULL(b.betid, 0) > 0 THEN b.betid
				ELSE b.transid
			END AS TransId,
			b.refno,
			b.custid,
			b.currency,
			b.recommend,
			CASE
				WHEN @Product IN ('Keno', 'Lottery', 'VB', 'PP', 'OneRNG', 'CC', 'SG', 'Allbet', 'SPR', 'VRG', 'TG', 'SBC', 
					'I4D', 'SXG', 'SAG', 'PGS', 'JK', 'H5LG', 'SLT', 'HB', 'WM', 'BG', 'VGA', 'CG', 'AP', 'APM', 'VS3', 'FGGL', 'MXG', 'TIP', 'JIG', 'YB', 'MGRNG', 'SEA') THEN b.matchid
				WHEN @Product IN ('Outright') THEN l.sporttype
				WHEN @EventType = 1 THEN m.sporttype
				WHEN @EventType = 5 THEN m3rd.SportType
				WHEN @RefTable IN (1, 2) THEN b.matchid
				WHEN @EventType = 3 THEN vr.SportType
				ELSE b.matchid
			END AS SportType,
			b.bettype,
			ISNULL(b.betid, 0) AS BetId,
			b.betteam,
			b.hdp1,
			b.hdp2,
			b.oddstype,
			b.odds,
			b.modds,
			ISNULL(b.oddsspread, 0) AS OddsSpread,
			b.stake,
			b.actual_stake,
			(b.winlost - b.actual_stake) AS WinLost,
			- (b.winlost - b.actual_stake) AS LicenseeWL,
			b.playercomm,
			b.comm,
			CASE
				WHEN @Product = 'TG' AND b.status = 'Won' AND b.modds = 0.25 THEN 'Half Won'
				WHEN @Product = 'TG' AND b.status = 'Lose' AND b.modds = -0.25 THEN 'Half Lose'
				ELSE b.status
			END AS Status,
			0 AS SettlementStatus,
			b.transdate,
			b.winlostdate,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			dp.IP,
			b.betfrom,
			CASE
				WHEN @EventType = 1 THEN m.leagueid
				WHEN @EventType = 5 THEN m3rd.League3rdId
				WHEN @Product IN ('Outright') THEN o.leagueid
				WHEN @EventType = 3 THEN vr.LeagueID
				ELSE 0
			END AS LeagueId,
			CASE
				WHEN @Product IN ('SB') THEN le.LeagueGroupID
				ELSE 0
			END AS LeagueGroupId,
			CASE
				WHEN @Product = 'TIP' THEN ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p74/@m)[1]','INT'), 0)
				ELSE b.matchid
			END AS MatchId,
			CASE
				WHEN @EventType = 1 THEN m.matchcode
				WHEN @Product IN ('Outright') THEN o.matchcode
				ELSE ''
			END AS MatchCode,
			CASE
				WHEN @Product IN ('Outright') THEN o.groupmatch
				ELSE ''
			END AS Race,
			CASE
				WHEN @Product IN ('SB') THEN m.GlobalShowTime
				WHEN @Product IN ('BTC') THEN m3rd.EndTime
				ELSE b.WinLostDate
			END AS EventDate,
			CASE
				WHEN @EventType = 1 THEN m.homeid
				WHEN @EventType = 5 THEN m3rd.HomeId
				WHEN @Product IN ('Outright') THEN o.teamid
				ELSE 0
			END AS HomeId,
			CASE
				WHEN @EventType = 1 THEN m.awayid
				WHEN @EventType = 5 THEN m3rd.AwayId
				ELSE 0
			END AS AwayId,
			CASE
				WHEN @EventType = 1 THEN m.betstatus
				ELSE ''
			END AS BetStatus,
			CASE
				WHEN @EventType = 1 THEN ISNULL(m.IsNeutral, 0)
				ELSE 0
			END AS IsNeutral,
			'' AS Placing,
			CASE
				WHEN @Product IN ('VS') THEN CONVERT(NVARCHAR(50), m.kickofftime)
				WHEN @EventType = 5 THEN CONVERT(NVARCHAR(50), m3rd.StartTime)
				ELSE ''
			END AS ShowTime,
			CASE
				WHEN @Product IN ('SB', 'VRG', 'SLT', 'H5LG') THEN ISNULL(b.betcheck, '')
				WHEN @Product IN ('Keno') THEN ISNULL(b.ComStatus, '')
				WHEN @EventType = 0 AND @RefTable = 0 THEN ISNULL(b.betcheck, '')
				ELSE ''
			END AS BetCheck,
			CASE
				WHEN @Product IN ('Keno', 'Lottery', 'OneRNG', 'CC', 'SG', 'VB', 
					'PP', 'VRG', 'TG', 'I4D', 'PGS', 'JK', 'H5LG', 'SLT', 'HB', 'CG', 'AP', 'APM', 'SEA') THEN ISNULL(b.transdesc, '')
				WHEN @EventType IN (1, 3) THEN ISNULL(b.transdesc, '')
				ELSE ''
			END AS TransDesc,
			CASE
				WHEN @Product IN ('SB') THEN ISNULL(b.betdaqid, -1)
				ELSE -1
			END AS BetdaqId,
			ISNULL(b.ExtraInfo, '') AS ExtraInfo,
			'' AS JackpotInfo,
			CASE
				WHEN @Product IN ('SB') AND b.ExtraInfo LIKE '%p25%' THEN
					ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p25/@s)[1]','MONEY'), 0)
				ELSE 0
			END AS OriginalStake,
			CASE
				WHEN @Product IN ('SB') AND b.stake <> 0 THEN -1
				ELSE 0
			END AS OriginalBetType,
			CASE
				WHEN @Product IN ('SB') THEN ISNULL(b.WalletType, 0)
				ELSE 0
			END AS WalletType,
			CASE
				WHEN @Product IN ('SB') AND b.stake <> 0 THEN ISNULL(b.RefCode, 0)
				ELSE 0
			END AS RefCode,
			CASE
				WHEN @Product IN ('H5LG', 'SLT', 'VRG') THEN CONVERT(VARCHAR(20), b.BetdaqId)
				ELSE ''
			END AS SiteId,
			4 AS WhTicket
		FROM bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK)
			LEFT JOIN bodb_Archive.dbo.match_bk AS m WITH (NOLOCK) ON @EventType = 1 AND b.matchid = m.matchid
			LEFT JOIN dbo.League AS le WITH (NOLOCK) ON @Product IN ('SB') AND le.leagueid = m.leagueid
			LEFT JOIN bodb_Archive.dbo.Match3rd_bk AS m3rd WITH (NOLOCK) ON @EventType = 5 AND m3rd.Match3rdId = b.matchid
			LEFT JOIN bodb_Archive.dbo.Outright_bk AS o WITH (NOLOCK) ON @Product IN ('Outright') AND b.matchid = o.orid
			LEFT JOIN dbo.League AS l WITH (NOLOCK) ON @Product IN ('Outright') AND o.leagueID = l.leagueID
			LEFT JOIN bodb_Archive.dbo.VSRaceInfo_bk AS vr WITH (NOLOCK) ON @EventType = 3 AND vr.EventID = b.matchid
			CROSS APPLY dbo.f_IP_Decompress(b.ip) AS dp
		WHERE b.transid IN (@TransId, @BonusTransId)
	END

	-- Get match info for Player Tips
	IF @Product = 'TIP'
	BEGIN
		IF EXISTS (	SELECT 1
					FROM @Data AS b
						INNER JOIN dbo.match AS m WITH (NOLOCK) ON m.matchid = b.MatchId)
		BEGIN
			UPDATE b
			SET
				LeagueId = m.leagueid,
				HomeId = m.homeid,
				AwayId = m.awayid,
				EventDate = m.GlobalShowTime
			FROM @Data AS b
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON m.matchid = b.MatchId
		END
		ELSE IF EXISTS ( SELECT 1
						FROM @Data AS b
							INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON m.matchid = b.MatchId)
		BEGIN
			UPDATE b
			SET
				LeagueId = m.leagueid,
				HomeId = m.homeid,
				AwayId = m.awayid,
				EventDate = m.GlobalShowTime
			FROM @Data AS b
				INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON m.matchid = b.MatchId
		END
		ELSE
		BEGIN
			UPDATE b
			SET
				LeagueId = m.leagueid,
				HomeId = m.homeid,
				AwayId = m.awayid,
				EventDate = m.GlobalShowTime
			FROM @Data AS b
				INNER JOIN bodb_Archive.dbo.match_bk AS m WITH (NOLOCK) ON m.matchid = b.MatchId
		END
	END

	-- Don't display Cash text for ticket from Cash Wallet only
	UPDATE @Data
	SET WalletType = 0
	WHERE WalletType = 2 AND RefCode = 0

	-- Display Cash/Bonus text for ticket from multiple wallets
	UPDATE @Data
	SET RefCode = 0
	WHERE RefCode <> 0

	-- BettransRnG tables
	IF @WhTicket = 0
	BEGIN
		SET @ProductId = 0
		SET @RefTable = 0
		SET @CustId = @OriginalCustId
		SET @MainCustId = 0

		IF @CustId <> -1
		BEGIN
			IF @RefNo <> 0		-- Search by refno
			BEGIN
				-- BettransRnG range
				IF @WhTicket = 0 AND @ExcludeBettrans = 0
				BEGIN
					SELECT TOP(1)
						@TransId = b.transid,
						@CustId = b.custid,
						@WinLostDate = b.winlostdate,
						@Recommend = b.recommend,
						@Currency = b.currency,
						@BetType = b.gameID,
						@ProductId = s.ProductID,
						@EventType = s.EventType,
						@RefTable = s.RefTable,
						@WhTicket = 5		-- BettransRnG
					FROM dbo.bettransRnG AS b WITH (NOLOCK)
						INNER JOIN @SportBettype AS s ON s.bettype = b.gameID
					WHERE b.transid = @RefNo
						AND (b.custid = @CustId OR @CustId = 0)
						AND b.winlostdate > @MoveBetsDay
				END

				-- BettransRnG14 range
				IF @WhTicket = 0
				BEGIN
					SELECT TOP(1)
						@TransId = b.transid,
						@CustId = b.custid,
						@WinLostDate = b.winlostdate,
						@Recommend = b.recommend,
						@Currency = b.currency,
						@BetType = b.gameID,
						@ProductId = s.ProductID,
						@EventType = s.EventType,
						@RefTable = s.RefTable,
						@WhTicket = 6		-- BettransRnG14
					FROM dbo.bettransRnG14 AS b WITH (NOLOCK)
						INNER JOIN @SportBettype AS s ON s.bettype = b.gameID
					WHERE b.transid = @RefNo
						AND (b.custid = @CustId OR @CustId = 0)
						AND b.winlostdate BETWEEN @BalanceUpDay AND @MoveBetsDay
				END

				-- BettransRnG_bk range
				IF @WhTicket = 0 AND @CustId <> 0
				BEGIN
					SELECT TOP(1)
						@TransId = b.transid,
						@CustId = b.custid,
						@WinLostDate = b.winlostdate,
						@Recommend = b.recommend,
						@Currency = b.currency,
						@BetType = b.gameID,
						@ProductId = s.ProductID,
						@EventType = s.EventType,
						@RefTable = s.RefTable,
						@WhTicket = 7		-- BettransRnG_bk
					FROM bodb_Archive.dbo.bettransRnG_bk AS b WITH (NOLOCK)
						INNER JOIN @SportBettype AS s ON s.bettype = b.gameID
					WHERE b.transid = @RefNo AND b.custid = @CustId
				END
			END
			ELSE IF ISNULL(@TxId, '') <> '' AND @CustId <> 0
			BEGIN
				-- BettransRnG range
				IF @WhTicket = 0 AND @ExcludeBettrans = 0
				BEGIN
					SELECT TOP(1)
						@TransId = b.transid,
						@CustId = b.custid,
						@WinLostDate = b.winlostdate,
						@Recommend = b.recommend,
						@Currency = b.currency,
						@BetType = b.gameID,
						@ProductId = s.ProductID,
						@EventType = s.EventType,
						@RefTable = s.RefTable,
						@WhTicket = 5		-- BettransRnG
					FROM dbo.bettransRnG AS b WITH (NOLOCK)
						INNER JOIN @SportBettype AS s ON s.bettype = b.gameID
					WHERE b.custid = @CustId
						AND b.winlostdate > @MoveBetsDay
						AND ISNULL(b.Additional, '') LIKE '%lt=' + @TxId + '%'
				END

				-- BettransRnG14 range
				IF @WhTicket = 0
				BEGIN
					SELECT TOP(1)
						@TransId = b.transid,
						@CustId = b.custid,
						@WinLostDate = b.winlostdate,
						@Recommend = b.recommend,
						@Currency = b.currency,
						@BetType = b.gameID,
						@ProductId = s.ProductID,
						@EventType = s.EventType,
						@RefTable = s.RefTable,
						@WhTicket = 6		-- BettransRnG14
					FROM dbo.bettransRnG14 AS b WITH (NOLOCK)
						INNER JOIN @SportBettype AS s ON s.bettype = b.gameID
					WHERE b.custid = @CustId
						AND b.winlostdate BETWEEN @BalanceUpDay AND @MoveBetsDay
						AND ISNULL(b.Additional, '') LIKE '%lt=' + @TxId + '%'
				END
			END

			IF @WhTicket > 0
			BEGIN
				IF @ViewSabaCoins = 0
					AND NOT EXISTS (SELECT 1 FROM @TempAg WHERE CustId = @Recommend AND Currency = @Currency)
				BEGIN
					SET @WhTicket = 0
				END
				ELSE IF @ViewSabaCoins = 1
				BEGIN
					SELECT @MainCustId = CASE
											WHEN CHARINDEX('SabaCoins$', username2) > 0
												THEN CAST(SUBSTRING(username2, CHARINDEX('SabaCoins$', username2) + LEN('SabaCoins$'), LEN(username2)) AS INT)
											ELSE 0
										END
					FROM dbo.Customer WITH (NOLOCK)
					WHERE custid = @CustId

					IF NOT EXISTS ( SELECT 1
									FROM @TempAg AS ta
										INNER JOIN dbo.Customer AS c WITH (NOLOCK) ON ta.CustId = c.recommend AND ta.Currency = c.currency
									WHERE c.custid = @MainCustId)
					BEGIN
						SET @WhTicket = 0
					END
				END
			END
		END
	END

	SET @Product = CASE
						WHEN @ProductId = 6 THEN 'OneRNG'	-- RNG Casino
						WHEN @ProductId = 22 THEN 'VB'		-- Macau Games
						WHEN @ProductId = 32 THEN 'PP'		-- Pragmatic Play Casino
						WHEN @ProductId = 34 THEN 'CC'		-- Card Club
						WHEN @ProductId = 36 THEN 'SG'		-- Spadegaming
						WHEN @ProductId = 42 THEN 'SBC'		-- Saba.club
						WHEN @ProductId = 55 THEN 'PGS'		-- PG Soft
						WHEN @ProductId = 56 THEN 'JK'		-- Joker
						WHEN @ProductId = 60 THEN 'MXG'		-- MaxGame
						WHEN @ProductId = 61 THEN 'HB'		-- Habanero
						WHEN @ProductId = 62 THEN 'CG'		-- CG
						WHEN @ProductId = 66 THEN 'VGA'		-- Vgaming
						WHEN @ProductId = 67 THEN 'AP'		-- AdvantPlay
						WHEN @ProductId = 68 THEN 'APM'		-- AdvantPlay Mini
						WHEN @ProductId = 72 THEN 'SEA'		-- SEAL Entertainment
						WHEN @ProductId = 73 THEN 'MGRNG'		-- MG-RNG
						WHEN @ProductId = 75 THEN 'JIG'			-- Jili
						ELSE 'Unknown'
					END

	IF @RefTable = 1
	BEGIN
		-- BettransRnG
		IF @WhTicket = 5
		BEGIN
			INSERT INTO @Data
			SELECT
				transid,
				transid AS RefNo,
				custid,
				currency,
				recommend,
				productID AS SportType,
				gameID AS BetType,
				0 AS BetId,
				ISNULL(GameId3rd, '') AS BetTeam,
				0 AS Hdp1,
				0 AS Hdp2,
				0 AS OddsType,
				CASE
					WHEN @Product IN ('PP', 'SBC', 'VGA', 'SG') AND statusID IN (111, 112, 113) THEN ISNULL(ContributionRate, 0)
					ELSE odds
				END AS Odds,
					0 AS MOdds,
				CASE
					WHEN @Product IN ('PP', 'SBC', 'VGA', 'SG') AND statusID IN (111, 112, 113) THEN ISNULL(BetStake, 0)
					ELSE 0
				END AS OddsSpread,
				stake,
				actual_stake,
				CASE
					WHEN statusID IN (0, 1) THEN 0
					ELSE winlost - actual_stake
				END AS WinLost,
				CASE
					WHEN statusID IN (0, 1) THEN 0
					ELSE - (winlost - actual_stake)
				END AS LicenseeWL,
				playercomm,
				CASE
					WHEN statusID IN (0, 1) THEN 0
					ELSE comm
				END AS Comm,
				status,
				0 AS SettlementStatus,
				transdate,
				winlostdate,
				0 AS LiveIndicator,
				0 AS LiveHomeScore,
				0 AS LiveAwayScore,
				ip,
				betfrom,
				0 AS LeagueId,
				0 AS LeagueGroupId,
				0 AS MatchId,
				CASE
					WHEN @Product IN ('SBC') THEN ISNULL(SiteID, '')
					ELSE Additional
				END AS MatchCode,
				'' AS Race,
				TransDate3rd AS EventDate,
				0 AS HomeId,
				0 AS AwayId,
				'' AS BetStatus,
				0 AS IsNeutral,
				'' AS Placing,
				'' AS ShowTime,
				TranId3rd AS BetCheck,
				transdesc,
				CASE
					WHEN @Product IN ('PP', 'SBC', 'VGA', 'SG') THEN ISNULL(RefNo2, -1)
					ELSE -1
				END AS BetdaqId,
				ExtraInfo,
				CASE
					WHEN @Product IN ('PP', 'SBC', 'VGA', 'SG') THEN ISNULL(JackpotInfo, '')
					ELSE ''
				END AS JackpotInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				ISNULL(SiteID, '') AS SiteId,
				5 AS WhTicket
			FROM dbo.bettransRnG WITH (NOLOCK)
			WHERE transid = @TransId
		END

		-- BettransRnG14
		IF @WhTicket = 6
		BEGIN
			INSERT INTO @Data
			SELECT
				transid,
				transid AS RefNo,
				custid,
				currency,
				recommend,
				productID AS SportType,
				gameID AS BetType,
				0 AS BetId,
				ISNULL(GameId3rd, '') AS BetTeam,
				0 AS Hdp1,
				0 AS Hdp2,
				0 AS OddsType,
				CASE
					WHEN @Product IN ('PP', 'SBC', 'VGA', 'SG') AND statusID IN (111, 112, 113) THEN ISNULL(ContributionRate, 0)
					ELSE odds
				END AS Odds,
					0 AS MOdds,
				CASE
					WHEN @Product IN ('PP', 'SBC', 'VGA', 'SG') AND statusID IN (111, 112, 113) THEN ISNULL(BetStake, 0)
					ELSE 0
				END AS OddsSpread,
				stake,
				actual_stake,
				CASE
					WHEN statusID IN (0, 1) THEN 0
					ELSE winlost - actual_stake
				END AS WinLost,
				CASE
					WHEN statusID IN (0, 1) THEN 0
					ELSE - (winlost - actual_stake)
				END AS LicenseeWL,
				playercomm,
				CASE
					WHEN statusID IN (0, 1) THEN 0
					ELSE comm
				END AS Comm,
				status,
				0 AS SettlementStatus,
				transdate,
				winlostdate,
				0 AS LiveIndicator,
				0 AS LiveHomeScore,
				0 AS LiveAwayScore,
				ip,
				betfrom,
				0 AS LeagueId,
				0 AS LeagueGroupId,
				0 AS MatchId,
				CASE
					WHEN @Product IN ('SBC') THEN ISNULL(SiteID, '')
					ELSE Additional
				END AS MatchCode,
				'' AS Race,
				TransDate3rd AS EventDate,
				0 AS HomeId,
				0 AS AwayId,
				'' AS BetStatus,
				0 AS IsNeutral,
				'' AS Placing,
				'' AS ShowTime,
				TranId3rd AS BetCheck,
				transdesc,
				CASE
					WHEN @Product IN ('PP', 'SBC', 'VGA', 'SG') THEN ISNULL(RefNo2, -1)
					ELSE -1
				END AS BetdaqId,
				ExtraInfo,
				CASE
					WHEN @Product IN ('PP', 'SBC', 'VGA', 'SG') THEN ISNULL(JackpotInfo, '')
					ELSE ''
				END AS JackpotInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				ISNULL(SiteID, '') AS SiteId,
				6 AS WhTicket
			FROM dbo.bettransRnG14 WITH (NOLOCK)
			WHERE transid = @TransId
		END

		-- BettransRnG_bk
		IF @WhTicket = 7
		BEGIN
			INSERT INTO @Data
			SELECT
				b.transid,
				b.transid AS RefNo,
				b.custid,
				b.currency,
				b.recommend,
				b.productID AS SportType,
				b.gameID AS BetType,
				0 AS BetId,
				ISNULL(GameId3rd, '') AS BetTeam,
				0 AS Hdp1,
				0 AS Hdp2,
				0 AS OddsType,
				CASE
					WHEN @Product IN ('PP', 'SBC', 'VGA', 'SG') AND b.statusID IN (111, 112, 113) THEN ISNULL(b.ContributionRate, 0)
					ELSE b.odds
				END AS Odds,
				0 AS MOdds,
				CASE
					WHEN @Product IN ('PP', 'SBC', 'VGA', 'SG') AND b.statusID IN (111, 112, 113) THEN ISNULL(b.BetStake, 0)
					ELSE 0
				END AS OddsSpread,
				b.stake,
				b.actual_stake,
				CASE
					WHEN b.statusID IN (0, 1) THEN 0
					ELSE b.winlost - b.actual_stake
				END AS WinLost,
				CASE
					WHEN b.statusID IN (0, 1) THEN 0
					ELSE - (b.winlost - b.actual_stake)
				END AS LicenseeWL,
				b.playercomm,
				CASE
					WHEN b.statusID IN (0, 1) THEN 0
					ELSE b.comm
				END AS Comm,
				b.status,
				0 AS SettlementStatus,
				b.transdate,
				b.winlostdate,
				0 AS LiveIndicator,
				0 AS LiveHomeScore,
				0 AS LiveAwayScore,
				dp.IP,
				b.betfrom,
				0 AS LeagueId,
				0 AS LeagueGroupId,
				0 AS MatchId,
				CASE
					WHEN @Product IN ('SBC') THEN ISNULL(SiteID, '')
					ELSE b.Additional
				END AS MatchCode,
				'' AS Race,
				TransDate3rd AS EventDate,
				0 AS HomeId,
				0 AS AwayId,
				'' AS BetStatus,
				0 AS IsNeutral,
				'' AS Placing,
				'' AS ShowTime,
				b.TranId3rd AS BetCheck,
				b.transdesc,
				CASE
					WHEN @Product IN ('PP', 'SBC', 'VGA', 'SG') THEN ISNULL(b.RefNo2, -1)
					ELSE -1
				END AS BetdaqId,
				ExtraInfo,
				CASE
					WHEN @Product IN ('PP', 'SBC', 'VGA', 'SG') THEN ISNULL(b.JackpotInfo, '')
					ELSE ''
				END AS JackpotInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				ISNULL(SiteID, '') AS SiteId,
				7 AS WhTicket
			FROM bodb_Archive.dbo.bettransRnG_bk AS b WITH (NOLOCK)
				CROSS APPLY dbo.f_IP_Decompress(b.ip) AS dp
			WHERE b.transid = @TransId
				 AND b.custid = @CustId
				 AND b.winlostdate = @WinLostDate
		END
	END

	-- BettransLC tables
	IF @WhTicket = 0
	BEGIN
		SET @ProductId = 0
		SET @RefTable = 0
		SET @CustId = @OriginalCustId
		SET @MainCustId = 0

		IF @CustId <> -1 AND @RefNo <> 0		-- Search by refno
		BEGIN
			-- BettransLC range
			IF @WhTicket = 0 AND @ExcludeBettrans = 0
			BEGIN
				SELECT TOP(1)
					@TransId = b.transid,
					@CustId = b.custid,
					@WinLostDate = b.winlostdate,
					@Recommend = b.recommend,
					@Currency = b.currency,
					@BetType = b.gameID,
					@ProductId = s.ProductID,
					@EventType = s.EventType,
					@RefTable = s.RefTable,
					@WhTicket = 8		-- bettransLC
				FROM dbo.bettransLC AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.bettype = b.gameID
				WHERE b.transid = @RefNo
					AND (b.custid = @CustId OR @CustId = 0)
					AND b.winlostdate > @MoveBetsDay
			END

			-- BettransLC14 range
			IF @WhTicket = 0
			BEGIN
				SELECT TOP(1)
					@TransId = b.transid,
					@CustId = b.custid,
					@WinLostDate = b.winlostdate,
					@Recommend = b.recommend,
					@Currency = b.currency,
					@BetType = b.gameID,
					@ProductId = s.ProductID,
					@EventType = s.EventType,
					@RefTable = s.RefTable,
					@WhTicket = 9		-- bettransLC14
				FROM dbo.bettransLC14 AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.bettype = b.gameID
				WHERE b.transid = @RefNo
					AND (b.custid = @CustId OR @CustId = 0)
					AND b.winlostdate BETWEEN @BalanceUpDay AND @MoveBetsDay
			END

			-- BettransLC_bk range
			IF @WhTicket = 0 AND @CustId <> 0
			BEGIN
				SELECT TOP(1)
					@TransId = b.transid,
					@CustId = b.custid,
					@WinLostDate = b.winlostdate,
					@Recommend = b.recommend,
					@Currency = b.currency,
					@BetType = b.gameID,
					@ProductId = s.ProductID,
					@EventType = s.EventType,
					@RefTable = s.RefTable,
					@WhTicket = 10		-- bettransLC_bk
				FROM bodb_Archive.dbo.bettransLC_bk AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.bettype = b.gameID
				WHERE b.transid = @RefNo AND b.custid = @CustId
			END

			IF @WhTicket > 0
			BEGIN
				IF @ViewSabaCoins = 0
					AND NOT EXISTS (SELECT 1 FROM @TempAg WHERE CustId = @Recommend AND Currency = @Currency)
				BEGIN
					SET @WhTicket = 0
				END
				ELSE IF @ViewSabaCoins = 1
				BEGIN
					SELECT @MainCustId = CASE
											WHEN CHARINDEX('SabaCoins$', username2) > 0
												THEN CAST(SUBSTRING(username2, CHARINDEX('SabaCoins$', username2) + LEN('SabaCoins$'), LEN(username2)) AS INT)
											ELSE 0
										END
					FROM dbo.Customer WITH (NOLOCK)
					WHERE custid = @CustId

					IF NOT EXISTS ( SELECT 1
									FROM @TempAg AS ta
										INNER JOIN dbo.Customer AS c WITH (NOLOCK) ON ta.CustId = c.recommend AND ta.Currency = c.currency
									WHERE c.custid = @MainCustId)
					BEGIN
						SET @WhTicket = 0
					END
				END
			END
		END
	END

	SET @Product = CASE
						WHEN @ProductId = 21 THEN 'AllBet'
						WHEN @ProductId = 45 THEN 'SXG'
						WHEN @ProductId = 51 THEN 'WM'
						WHEN @ProductId = 57 THEN 'BG'
						WHEN @ProductId = 70 THEN 'FGGL'
						WHEN @ProductId = 76 THEN 'YB'
						ELSE 'Unknown'
					END

	IF @RefTable = 2
	BEGIN
		-- BettransLC
		IF @WhTicket = 8
		BEGIN
			INSERT INTO @Data
			SELECT
				transid,
				transid AS RefNo,
				custid,
				currency,
				recommend,
				productID AS SportType,
				gameID AS BetType,
				0 AS BetId,
				'' AS BetTeam,
				0 AS Hdp1,
				0 AS Hdp2,
				0 AS OddsType,
				odds,
				0 AS MOdds,
				0 AS OddsSpread,
				stake,
				actual_stake,
				CASE
					WHEN statusID IN (0, 1) THEN 0
					ELSE winlost - actual_stake
				END AS WinLost,
				CASE
					WHEN statusID IN (0, 1) THEN 0
					ELSE - (winlost - actual_stake)
				END AS LicenseeWL,
				playercomm,
				comm,
				status,
				0 AS SettlementStatus,
				transdate,
				winlostdate,
				0 AS LiveIndicator,
				0 AS LiveHomeScore,
				0 AS LiveAwayScore,
				ip,
				betfrom,
				currency AS LeagueId,
				0 AS LeagueGroupId,
				0 AS MatchId,
				GameId3rd AS MatchCode,
				'' AS Race,
				TransDate3rd AS EventDate,
				0 AS HomeId,
				0 AS AwayId,
				'' AS BetStatus,
				0 AS IsNeutral,
				'' AS Placing,
				'' AS ShowTime,
				TranId3rd AS BetCheck,
				transdesc,
				-1 AS BetdaqId,
				ExtraInfo,
				'' AS JackpotInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				SiteID,
				8 AS WhTicket
			FROM dbo.bettransLC WITH (NOLOCK)
			WHERE transid = @TransId
		END

		-- BettransLC14
		IF @WhTicket = 9
		BEGIN
			INSERT INTO @Data
			SELECT
				transid,
				transid AS RefNo,
				custid,
				currency,
				recommend,
				productID AS SportType,
				gameID AS BetType,
				0 AS BetId,
				'' AS BetTeam,
				0 AS Hdp1,
				0 AS Hdp2,
				0 AS OddsType,
				odds,
				0 AS MOdds,
				0 AS OddsSpread,
				stake,
				actual_stake,
				CASE
					WHEN statusID IN (0, 1) THEN 0
					ELSE winlost - actual_stake
				END AS WinLost,
				CASE
					WHEN statusID IN (0, 1) THEN 0
					ELSE - (winlost - actual_stake)
				END AS LicenseeWL,
				playercomm,
				comm,
				status,
				0 AS SettlementStatus,
				transdate,
				winlostdate,
				0 AS LiveIndicator,
				0 AS LiveHomeScore,
				0 AS LiveAwayScore,
				ip,
				betfrom,
				currency AS LeagueId,
				0 AS LeagueGroupId,
				0 AS MatchId,
				GameId3rd AS MatchCode,
				'' AS Race,
				TransDate3rd AS EventDate,
				0 AS HomeId,
				0 AS AwayId,
				'' AS BetStatus,
				0 AS IsNeutral,
				'' AS Placing,
				'' AS ShowTime,
				TranId3rd AS BetCheck,
				transdesc,
				-1 AS BetdaqId,
				ExtraInfo,
				'' AS JackpotInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				SiteID,
				9 AS WhTicket
			FROM dbo.bettransLC14 WITH (NOLOCK)
			WHERE transid = @TransId
		END

		-- BettransLC_bk
		IF @WhTicket = 10
		BEGIN
			INSERT INTO @Data
			SELECT
				b.transid,
				b.transid AS RefNo,
				b.custid,
				b.currency,
				b.recommend,
				b.productID AS SportType,
				b.gameID AS BetType,
				0 AS BetId,
				'' AS BetTeam,
				0 AS Hdp1,
				0 AS Hdp2,
				0 AS OddsType,
				b.odds,
				0 AS MOdds,
				0 AS OddsSpread,
				b.stake,
				b.actual_stake,
				CASE
					WHEN b.statusID IN (0, 1) THEN 0
					ELSE b.winlost - b.actual_stake
				END AS WinLost,
				CASE
					WHEN b.statusID IN (0, 1) THEN 0
					ELSE - (b.winlost - b.actual_stake)
				END AS LicenseeWL,
				b.playercomm,
				b.comm,
				b.status,
				0 AS SettlementStatus,
				b.transdate,
				b.winlostdate,
				0 AS LiveIndicator,
				0 AS LiveHomeScore,
				0 AS LiveAwayScore,
				dp.IP,
				b.betfrom,
				b.currency AS LeagueId,
				0 AS LeagueGroupId,
				0 AS MatchId,
				b.GameId3rd AS MatchCode,
				'' AS Race,
				TransDate3rd AS EventDate,
				0 AS HomeId,
				0 AS AwayId,
				'' AS BetStatus,
				0 AS IsNeutral,
				'' AS Placing,
				'' AS ShowTime,
				b.TranId3rd AS BetCheck,
				b.transdesc,
				-1 AS BetdaqId,
				ExtraInfo,
				'' AS JackpotInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				b.SiteID,
				10 AS WhTicket
			FROM bodb_Archive.dbo.bettransLC_bk AS b WITH (NOLOCK)
				CROSS APPLY dbo.f_IP_Decompress(b.ip) AS dp
			WHERE b.transid = @TransId
				AND b.custid = @CustId
				AND b.winlostdate = @WinLostDate
		END
	END

	-- Bettransg tables
	IF @WhTicket = 0
	BEGIN
		SET @ProductId = 0
		SET @CustId = @OriginalCustId
		SET @MainCustId = 0

		IF @CustId <> -1 AND @RefNo <> 0		-- Search by refno
		BEGIN
			-- Bettransg range
			IF @WhTicket = 0 AND @ExcludeBettrans = 0
			BEGIN
				SELECT TOP(1)
					@TransId = b.transid,
					@CustId = b.custid,
					@WinLostDate = b.winlostdate,
					@Recommend = blc.recommend,
					@Currency = blc.currency,
					@BetType = b.bettype,
					@ProductId = s.ProductID,
					@EventType = s.EventType,
					@WhTicket = 11		-- bettransg
				FROM dbo.bettransg AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.bettype = b.bettype
					INNER JOIN dbo.bettransLC AS blc WITH (NOLOCK) ON b.refno = blc.transid AND b.custid = blc.custid
				WHERE b.transid = @RefNo
					AND (b.custid = @CustId OR @CustId = 0)
					AND b.winlostdate > @MoveBetsDay
			END

			-- Bettransg14 range
			IF @WhTicket = 0
			BEGIN
				SELECT TOP(1)
					@TransId = b.transid,
					@CustId = b.custid,
					@WinLostDate = b.winlostdate,
					@Recommend = blc.recommend,
					@Currency = blc.currency,
					@BetType = b.bettype,
					@ProductId = s.ProductID,
					@EventType = s.EventType,
					@WhTicket = 12		-- bettransg14
				FROM dbo.bettransg14 AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.bettype = b.bettype
					INNER JOIN dbo.bettransLC14 AS blc WITH (NOLOCK) ON b.refno = blc.transid AND b.custid = blc.custid
				WHERE b.transid = @RefNo
					AND (b.custid = @CustId OR @CustId = 0)
					AND b.winlostdate BETWEEN @BalanceUpDay AND @MoveBetsDay
			END

			-- Bettransg bk range
			IF @WhTicket = 0 AND @CustId <> 0
			BEGIN
				SELECT TOP(1)
					@TransId = b.transid,
					@CustId = b.custid,
					@WinLostDate = b.winlostdate,
					@Recommend = blc.recommend,
					@Currency = blc.currency,
					@BetType = b.bettype,
					@ProductId = s.ProductID,
					@EventType = s.EventType,
					@WhTicket = 13		-- bettransg bk
				FROM bodb_Archive.dbo.bettransg AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.bettype = b.bettype
					INNER JOIN bodb_Archive.dbo.bettransLC_bk AS blc WITH (NOLOCK) ON b.refno = blc.transid AND b.custid = blc.custid
				WHERE b.transid = @RefNo
					AND (b.custid = @CustId OR @CustId = 0)
			END

			IF @WhTicket > 0
			BEGIN
				IF @ViewSabaCoins = 0
					AND NOT EXISTS (SELECT 1 FROM @TempAg WHERE CustId = @Recommend AND Currency = @Currency)
				BEGIN
					SET @WhTicket = 0
				END
				ELSE IF @ViewSabaCoins = 1
				BEGIN
					SELECT @MainCustId = CASE
											WHEN CHARINDEX('SabaCoins$', username2) > 0
												THEN CAST(SUBSTRING(username2, CHARINDEX('SabaCoins$', username2) + LEN('SabaCoins$'), LEN(username2)) AS INT)
											ELSE 0
										END
					FROM dbo.Customer WITH (NOLOCK)
					WHERE custid = @CustId

					IF NOT EXISTS ( SELECT 1
									FROM @TempAg AS ta
										INNER JOIN dbo.Customer AS c WITH (NOLOCK) ON ta.CustId = c.recommend AND ta.Currency = c.currency
									WHERE c.custid = @MainCustId)
					BEGIN
						SET @WhTicket = 0
					END
				END
			END
		END
	END

	SET @Product = CASE
						WHEN @ProductId = 39 THEN 'SAG'
						ELSE 'Unknown'
					END

	IF @Product <> 'Unknown'
	BEGIN
		-- Bettransg
		IF @WhTicket = 11
		BEGIN
			INSERT INTO @Data
			SELECT
				b.transid,
				blc.transid AS RefNo,
				b.custid,
				blc.currency,
				blc.recommend,
				blc.productID AS SportType,
				blc.gameID AS BetType,
				0 AS BetId,
				ISNULL(b.BetID3rd, '') AS BetTeam,
				0 AS Hdp1,
				0 AS Hdp2,
				0 AS OddsType,
				b.odds,
				0 AS MOdds,
				0 AS OddsSpread,
				b.stake,
				b.actual_stake,
				CASE
					WHEN b.statusID IN (0, 1) THEN 0
					ELSE b.winlost - b.actual_stake
				END AS WinLost,
				CASE
					WHEN b.statusID IN (0, 1) THEN 0
					ELSE - (b.winlost - b.actual_stake)
				END AS LicenseeWL,
				b.playercomm,
				b.comm,
				b.status,
				0 AS SettlementStatus,
				b.transdate,
				b.winlostdate,
				0 AS LiveIndicator,
				0 AS LiveHomeScore,
				0 AS LiveAwayScore,
				blc.ip,
				b.betfrom,
				0 AS LeagueId,
				0 AS LeagueGroupId,
				0 AS MatchId,
				blc.GameId3rd AS MatchCode,
				'' AS Race,
				NULL AS EventDate,
				0 AS HomeId,
				0 AS AwayId,
				'' AS BetStatus,
				0 AS IsNeutral,
				'' AS Placing,
				'' AS ShowTime,
				ISNULL(b.TransDesc, '') AS BetCheck,
				blc.transdesc,
				-1 AS BetdaqId,
				b.ExtraInfo,
				'' AS JackpotInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				blc.SiteID,
				11 AS WhTicket
			FROM dbo.bettransg AS b WITH (NOLOCK)
				INNER JOIN dbo.bettransLC AS blc WITH (NOLOCK) ON blc.transid = b.refno AND blc.custid = b.custid
			WHERE b.transid = @TransId
		END

		-- Bettransg14
		IF @WhTicket = 12
		BEGIN
			INSERT INTO @Data
			SELECT
				b.transid,
				blc.transid AS RefNo,
				b.custid,
				blc.currency,
				blc.recommend,
				blc.productID AS SportType,
				blc.gameID AS BetType,
				0 AS BetId,
				ISNULL(b.BetID3rd, '') AS BetTeam,
				0 AS Hdp1,
				0 AS Hdp2,
				0 AS OddsType,
				b.odds,
				0 AS MOdds,
				0 AS OddsSpread,
				b.stake,
				b.actual_stake,
				CASE
					WHEN b.statusID IN (0, 1) THEN 0
					ELSE b.winlost - b.actual_stake
				END AS WinLost,
				CASE
					WHEN b.statusID IN (0, 1) THEN 0
					ELSE - (b.winlost - b.actual_stake)
				END AS LicenseeWL,
				b.playercomm,
				b.comm,
				b.status,
				0 AS SettlementStatus,
				b.transdate,
				b.winlostdate,
				0 AS LiveIndicator,
				0 AS LiveHomeScore,
				0 AS LiveAwayScore,
				blc.ip,
				b.betfrom,
				0 AS LeagueId,
				0 AS LeagueGroupId,
				0 AS MatchId,
				blc.GameId3rd AS MatchCode,
				'' AS Race,
				NULL AS EventDate,
				0 AS HomeId,
				0 AS AwayId,
				'' AS BetStatus,
				0 AS IsNeutral,
				'' AS Placing,
				'' AS ShowTime,
				ISNULL(b.TransDesc, '') AS BetCheck,
				blc.transdesc,
				-1 AS BetdaqId,
				b.ExtraInfo,
				'' AS JackpotInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				blc.SiteID,
				12 AS WhTicket
			FROM dbo.bettransg14 AS b WITH (NOLOCK)
				INNER JOIN dbo.bettransLC14 AS blc WITH (NOLOCK) ON blc.transid = b.refno AND blc.custid = b.custid
			WHERE b.transid = @TransId
		END

		-- Bettransg bk
		IF @WhTicket = 13
		BEGIN
			INSERT INTO @Data
			SELECT
				b.transid,
				blc.transid AS RefNo,
				b.custid,
				blc.currency,
				blc.recommend,
				blc.productID AS SportType,
				blc.gameID AS BetType,
				0 AS BetId,
				ISNULL(b.BetID3rd, '') AS BetTeam,
				0 AS Hdp1,
				0 AS Hdp2,
				0 AS OddsType,
				b.odds,
				0 AS MOdds,
				0 AS OddsSpread,
				b.stake,
				b.actual_stake,
				CASE
					WHEN b.statusID IN (0, 1) THEN 0
					ELSE b.winlost - b.actual_stake
				END AS WinLost,
				CASE
					WHEN b.statusID IN (0, 1) THEN 0
					ELSE - (b.winlost - b.actual_stake)
				END AS LicenseeWL,
				b.playercomm,
				b.comm,
				b.status,
				0 AS SettlementStatus,
				b.transdate,
				b.winlostdate,
				0 AS LiveIndicator,
				0 AS LiveHomeScore,
				0 AS LiveAwayScore,
				dp.IP,
				b.betfrom,
				0 AS LeagueId,
				0 AS LeagueGroupId,
				0 AS MatchId,
				blc.GameId3rd AS MatchCode,
				'' AS Race,
				NULL AS EventDate,
				0 AS HomeId,
				0 AS AwayId,
				'' AS BetStatus,
				0 AS IsNeutral,
				'' AS Placing,
				'' AS ShowTime,
				ISNULL(b.TransDesc, '') AS BetCheck,
				blc.transdesc,
				-1 AS BetdaqId,
				b.ExtraInfo,
				'' AS JackpotInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				blc.SiteID,
				12 AS WhTicket
			FROM bodb_Archive.dbo.bettransg AS b WITH (NOLOCK)
				INNER JOIN bodb_Archive.dbo.bettransLC_bk AS blc WITH (NOLOCK) ON blc.transid = b.refno AND blc.custid = b.custid
				CROSS APPLY dbo.f_IP_Decompress(blc.ip) AS dp
			WHERE b.transid = @TransId
				AND b.custid = @CustId
				AND b.winlostdate = @WinLostDate
		END
	END

	IF @ViewSabaCoins = 0
	BEGIN
		DELETE @Data
		WHERE Currency NOT IN (SELECT DISTINCT Currency FROM @TempAg)
	END

	DECLARE @ExFromDate SMALLDATETIME,
		@ExToDate SMALLDATETIME

	SELECT
		@ExFromDate = MIN(WinLostDate),
		@ExToDate = MAX(WinLostDate)
	FROM @Data

	-- Get exchange rate
	DECLARE @ExchangeRate AS TABLE (
		ExchangeId					INT,
		FirstExchangeDateByMonth	SMALLDATETIME,
		LastExchangeDateByMonth		SMALLDATETIME,
		Rate						FLOAT
	)

	IF @BaseCurrency <> ''
	BEGIN
		INSERT INTO @ExchangeRate
		SELECT
			e.ExchangeId,
			e.FromDate,
			e.ToDate,
			e.Rate
		FROM dbo.Lrf_f_GetExchangeRate(@ExFromDate, @ExToDate, @BaseCurrency, '') AS e
		WHERE EXISTS (SELECT 1 FROM @Data
					WHERE Currency = e.ExchangeId
						AND WinLostDate BETWEEN e.FromDate AND e.ToDate	)
	END

	-- Get ticket detail
	-- Virtual Sports
	SET @WhTicket = 0

	SELECT
		@WhTicket = b.WhTicket,
		@TransId = b.transid
	FROM @Data AS b
		INNER JOIN @SportBettype AS sbt ON sbt.bettype = b.Bettype
	WHERE sbt.ProductID = 5 AND sbt.EventType = 3

	IF @WhTicket = 2
	BEGIN
		INSERT INTO @Detail
		SELECT
			bm.refno,
			bm.odds,
			bm.stake * ISNULL(e.Rate, 1) AS Stake,
			bm.status,
			bm.apositiontaking,
			bm.bettype,
			bm.betteam
		FROM dbo.bettransm AS bm WITH (NOLOCK)
			INNER JOIN @Data AS b ON bm.refno = b.RefNo AND bm.custid = @CustId
			INNER JOIN @SportBettype AS sbt ON bm.bettype = sbt.Bettype
			LEFT JOIN @ExchangeRate AS e
				ON e.ExchangeId = b.Currency
				AND b.WinLostDate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth
		WHERE b.TransId = @TransId
			AND sbt.ProductID = 5
			AND sbt.EventType = 3
	END

	IF @WhTicket = 3
	BEGIN
		INSERT INTO @Detail
		SELECT
			bm.refno,
			bm.odds,
			bm.stake * ISNULL(e.Rate, 1) AS Stake,
			bm.status,
			bm.apositiontaking,
			bm.bettype,
			bm.betteam
		FROM dbo.bettransm14 AS bm WITH (NOLOCK)
			INNER JOIN @Data AS b ON bm.refno = b.RefNo AND bm.custid = @CustId
			INNER JOIN @SportBettype AS sbt ON bm.bettype = sbt.Bettype
			LEFT JOIN @ExchangeRate AS e
				ON e.ExchangeId = b.Currency
				AND b.WinLostDate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth
		WHERE b.TransId = @TransId
			AND sbt.ProductID = 5
			AND sbt.EventType = 3
	END

	IF @WhTicket = 4
	BEGIN
		INSERT INTO @Detail
		SELECT
			bm.refno,
			bm.odds,
			bm.stake * ISNULL(e.Rate, 1) AS Stake,
			bm.status,
			bm.apositiontaking,
			bm.bettype,
			bm.betteam
		FROM bodb_Archive.dbo.bettransm AS bm WITH (NOLOCK)
			INNER JOIN @Data AS b ON bm.refno = b.RefNo AND bm.custid = @CustId
			INNER JOIN @SportBettype AS sbt ON bm.bettype = sbt.Bettype
			LEFT JOIN @ExchangeRate AS e
				ON e.ExchangeId = b.Currency
				AND b.WinLostDate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth
		WHERE b.TransId = @TransId
			AND sbt.ProductID = 5
			AND sbt.EventType = 3
	END

	DECLARE @Nickname VARCHAR(50)

	IF EXISTS (SELECT 1 FROM @Data)
	BEGIN
		SELECT
			@Username = username,
			@Nickname = SUBSTRING(username2, CHARINDEX('$', username2) + 1, LEN(username2) - CHARINDEX('$', username2))
		FROM dbo.Customer WITH (NOLOCK)
		WHERE custid = CASE
							WHEN @ViewSabaCoins = 0 THEN @CustId
							ELSE @MainCustId
						END
	END

	SELECT
		a.CustId,
		@Username AS Username,
		@Nickname AS NickName,
		a.TransId,
		a.RefNo,
		a.BetId,
		a.TransDate,
		a.WinLostDate,
		a.SportType,
		a.BetType,
		a.BetTeam,
		a.Hdp1,
		a.Hdp2,
		a.Odds,
		a.MOdds,
		a.OddsType,
		a.OddsSpread,
		a.Status,
		a.SettlementStatus,
		a.LiveIndicator,
		a.LiveHomeScore,
		a.LiveAwayScore,
		a.Race,
		a.LeagueId,
		a.LeagueGroupId,
		a.MatchId,
		a.MatchCode,
		a.Race,
		a.EventDate,
		a.HomeId,
		a.AwayId,
		a.IsNeutral,
		a.BetStatus,
		a.Placing,
		a.ShowTime,
		a.Currency,
		CAST(a.Stake * ISNULL(e.Rate, 1) AS DECIMAL(19, 8)) AS Stake,
		CAST(a.Actual_Stake * ISNULL(e.Rate, 1) AS DECIMAL(19, 8)) AS Actual_Stake,
		CAST(a.WinLost * ISNULL(e.Rate, 1) AS DECIMAL(19, 8)) AS WinLost,
		CAST(a.LicenseeWL * ISNULL(e.Rate, 1) AS DECIMAL(19, 8)) AS LicenseeWL,
		CAST(a.PlayerComm * ISNULL(e.Rate, 1) AS DECIMAL(19, 8)) AS PlayerComm,
		CAST(a.Comm * ISNULL(e.Rate, 1) AS DECIMAL(19, 8)) AS Comm,
		a.Ip,
		a.BetFrom,
		a.BetCheck,
		a.TransDesc,
		a.BetdaqId,
		a.ExtraInfo,
		a.JackpotInfo,
		a.OriginalStake * ISNULL(e.Rate, 1) AS OriginalStake,
		a.OriginalBetType,
		a.WalletType,
		a.RefCode,
		a.SiteId
	FROM @Data AS a
		LEFT JOIN @ExchangeRate AS e
			ON e.ExchangeId = a.Currency
			AND a.WinLostDate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth
	ORDER BY a.TransDate ASC

	SELECT DISTINCT * FROM @Detail
END
GO
