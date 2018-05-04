/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" viewers="vnteam" isFunction="0" isNested="0"></info>*/
USE bodb02
GO

ALTER PROCEDURE [dbo].[Age_CoreBetList_SMAEventBettype_SelBetTicket]
	@CustId				INT				= NULL
	, @Username			NVARCHAR(50)	= NULL
	, @RoleId			INT
	, @MatchId			INT
	-- PRODUCT - BETTYPE - STATUS
	, @TransStatus		[dbo].[TVP_BetTicketStatus]		READONLY
	, @BettypeMatrix	[dbo].[TVP_SportBettypeMatrix]	READONLY
	, @Language			VARCHAR(2)		= 'E'
	, @LiveIndicator	INT				= 0
	, @BetTeam			NVARCHAR(20)	= NULL
	, @ColumnOutput		VARCHAR(MAX)	= NULL
	, @Error			INT				= 0
	, @ErrorMsg			NVARCHAR(250)	= NULL
AS

/*
	Created: Bobby
	Task: Aphla site - refactor betlist core 
	DB: DBAGE.bodb02
	Original:

	Revisions:
		- 20150504@Bobby: Create new SP
		- 20150706@Bobby: Exclude Metric Gaming running ticket from bettrans table
		- 20150910@Bobby: Enhance performance for SP core. Apply TVP for input parameters
		- 20160111@Kos: Add @TransStatus param to support RNG Casino Single Wallet [#Redmine: 48958]
		- 20171030@Kos: Support Bullfighting [#Redmine: 84961]
		- 20180330@Kos: Change to use index in srecommend and mrecommend [#Redmine: 91150]

	Param's Explanation:
		- @BettypeMatrix	: XML.format(<BettypeMatrix><row ProductID="1" Bettype="1" EventType="1" /></BettypeMatrix>)
		- @TransStatus		: string formation (0, 1, 102, 103, 111, 112, 113)

	Wrapped SP List:
		- Age_BetList_SelRunningByBettypeMatch_Ag
		- Age_BetList_SelRunningByBettypeMatch_MAg
		- Age_BetList_SelRunningByBettypeMatch_SAg
		- Age_BetList_SelWinlossByBettypeMatch_Ag
		- Age_BetList_SelWinlossByBettypeMatch_MAg
		- Age_BetList_SelWinlossByBettypeMatch_SAg
	
*/

BEGIN
	SET NOCOUNT ON;

	DECLARE @IsBet14	BIT,
		@tempCust		dbo.TVP_TicketSportBettype

	-- RESET output
	SELECT @Error	= 0,
		@ErrorMsg	= ''

	-- CHECK bettrans14
	IF EXISTS (SELECT 1 FROM @BettypeMatrix WHERE EventType = 1)
	BEGIN
		SELECT TOP(1) @IsBet14 = CAST(1 AS BIT)
		FROM dbo.match14 WITH (NOLOCK)
		WHERE matchid = @MatchId
	END
	ELSE
	BEGIN
		SELECT TOP(1) @IsBet14 = CAST(1 AS BIT)
		FROM dbo.Match3rd14 WITH (NOLOCK)
		WHERE Match3rdId = @MatchId
	END

	SET @IsBet14 = ISNULL(@IsBet14, 0)

	IF @CustId IS NULL
	BEGIN
		SELECT @CustId = custid
		FROM dbo.customer WITH (NOLOCK)
		WHERE username = @Username
	END

	CREATE TABLE #tempRawData (
		TransId		BIGINT,
		RefNo		BIGINT,
		CustId		INT,
		ProductId	TINYINT,
		BetType		SMALLINT,
		EventType	TINYINT,
		WhTicket	TINYINT
	)
	
	-- Bettrans
	IF @IsBet14 = 0
	BEGIN
		IF @RoleId = 1		-- Member
		BEGIN
			INSERT INTO #tempRawData
			SELECT
				b.transid,
				b.refno,
				b.custid,
				bt.ProductId,
				b.bettype,
				bt.EventType,
				1 AS WhTicket
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN @BettypeMatrix AS bt ON b.bettype = bt.bettype
				INNER JOIN @TransStatus AS stt ON b.statusid = stt.statusid
			WHERE b.custid = @CustId
				AND b.matchid = @MatchId
				AND (bt.SubProduct NOT IN ('MG-SuperLive')
					OR bt.SubProduct IN ('MG-SuperLive') AND b.StatusId NOT IN (0, 1))
		END

		IF @RoleId = 2		-- Agent
		BEGIN
			INSERT INTO #tempRawData
			SELECT
				b.transid,
				b.refno,
				b.custid,
				bt.ProductId,
				b.bettype,
				bt.EventType,
				1 AS WhTicket
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN @BettypeMatrix AS bt ON b.bettype = bt.bettype
				INNER JOIN @TransStatus AS stt ON b.statusid = stt.statusid
			WHERE b.recommend = @CustId
				AND b.matchid = @MatchId
				AND (bt.SubProduct NOT IN ('MG-SuperLive')
					OR bt.SubProduct IN ('MG-SuperLive') AND b.StatusId NOT IN (0, 1))
		END

		IF @RoleId = 3		-- Master
		BEGIN
			INSERT INTO #tempRawData
			SELECT
				b.transid,
				b.refno,
				b.custid,
				bt.ProductId,
				b.bettype,
				bt.EventType,
				1 AS WhTicket
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN @BettypeMatrix AS bt ON b.bettype = bt.bettype
				INNER JOIN @TransStatus AS stt ON b.statusid = stt.statusid
			WHERE b.mrecommend = @CustId
				AND b.matchid = @MatchId
				AND (bt.SubProduct NOT IN ('MG-SuperLive')
					OR bt.SubProduct IN ('MG-SuperLive') AND b.StatusId NOT IN (0, 1))
		END

		IF @RoleId = 4		-- Super
		BEGIN
			INSERT INTO #tempRawData
			SELECT
				b.transid,
				b.refno,
				b.custid,
				bt.ProductId,
				b.bettype,
				bt.EventType,
				1 AS WhTicket
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN @BettypeMatrix AS bt ON b.bettype = bt.bettype
				INNER JOIN @TransStatus AS stt ON b.statusid = stt.statusid
			WHERE b.srecommend = @CustId
				AND b.matchid = @MatchId
				AND (bt.SubProduct NOT IN ('MG-SuperLive')
					OR bt.SubProduct IN ('MG-SuperLive') AND b.StatusId NOT IN (0, 1))
		END
	END

	-- Bettrans14
	IF @IsBet14 = 1
	BEGIN
		IF @RoleId = 1		-- Member
		BEGIN
			INSERT INTO #tempRawData
			SELECT
				b.transid,
				b.refno,
				b.custid,
				bt.ProductId,
				b.bettype,
				bt.EventType,
				2 AS WhTicket
			FROM dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN @BettypeMatrix AS bt ON b.bettype = bt.Bettype
				INNER JOIN @TransStatus AS stt ON b.statusid = stt.statusid
			WHERE b.custid = @CustId
				AND b.matchid = @MatchId
		END

		IF @RoleId = 2		-- Agent
		BEGIN
			INSERT INTO #tempRawData
			SELECT
				b.transid,
				b.refno,
				b.custid,
				bt.ProductId,
				b.bettype,
				bt.EventType,
				2 AS WhTicket
			FROM dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN @BettypeMatrix AS bt ON b.bettype = bt.Bettype
				INNER JOIN @TransStatus AS stt ON b.statusid = stt.statusid
			WHERE b.recommend = @CustId
				AND b.matchid = @MatchId
		END

		IF @RoleId = 3		-- Master
		BEGIN
			INSERT INTO #tempRawData
			SELECT
				b.transid,
				b.refno,
				b.custid,
				bt.ProductId,
				b.bettype,
				bt.EventType,
				2 AS WhTicket
			FROM dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN @BettypeMatrix AS bt ON b.bettype = bt.Bettype
				INNER JOIN @TransStatus AS stt ON b.statusid = stt.statusid
			WHERE b.mrecommend = @CustId
				AND b.matchid = @MatchId
		END

		IF @RoleId = 4		-- Super
		BEGIN
			WITH CteRecommend ( custid )
			AS (
				SELECT custid
				FROM dbo.Customer WITH (NOLOCK)
				WHERE srecommend = @CustId AND roleid = 3
			)
			INSERT INTO #tempRawData
			SELECT
				b.transid,
				b.refno,
				b.custid,
				bt.ProductId,
				b.bettype,
				bt.EventType,
				2 AS WhTicket
			FROM dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN CteRecommend AS c ON b.mrecommend = c.custid
				INNER JOIN @BettypeMatrix AS bt ON b.bettype = bt.Bettype
				INNER JOIN @TransStatus AS stt ON b.statusid = stt.statusid
			WHERE b.matchid = @MatchId
		END
	END

	IF EXISTS (SELECT TOP(1) 1 FROM #tempRawData WHERE ProductId = 3 AND EventType = 1 )
	BEGIN
		IF @IsBet14 = 0
		BEGIN
			DELETE c
			FROM #tempRawData AS c
				INNER JOIN dbo.bettrans AS b WITH (NOLOCK)
					ON c.transid = b.transid AND c.custid = b.custid
			WHERE c.WhTicket = 1
				AND c.ProductId = 3
				AND c.eventType = 1
				AND ((@LiveIndicator IS NOT NULL AND b.Liveindicator <> @LiveIndicator)
					OR (LEN(@BetTeam) > 0 AND b.betteam <> @BetTeam))
		END

		IF @IsBet14 = 1
		BEGIN
			DELETE c
			FROM #tempRawData AS c
				INNER JOIN dbo.bettrans14 AS b WITH (NOLOCK)
					ON c.transid = b.transid AND c.custid = b.custid
			WHERE c.WhTicket = 2
				AND c.ProductId = 3
				AND c.eventType = 1
				AND ((@LiveIndicator IS NOT NULL AND b.Liveindicator <> @LiveIndicator)
					OR (LEN(@BetTeam) > 0 AND b.betteam <> @BetTeam))
		END
	END

	INSERT INTO @tempCust (
		TransID,
		Refno,
		CustID,
		ProductID,
		Bettype,
		EventType,
		WhTicket )
	SELECT
		TransID,
		Refno,
		CustID,
		ProductID,
		Bettype,
		EventType,
		WhTicket
	FROM #tempRawData

	-- Get ticket info
	EXEC [dbo].[Age_CoreBetList_BetTicket_SelMainInfo]
		@tempCust = @tempCust,
		@TransStatus = @TransStatus,
		@ColumnOutput = @ColumnOutput
END


GO
GRANT EXECUTE ON [dbo].[Age_CoreBetList_SMAEventBettype_SelBetTicket] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_CoreBetList_SMAEventBettype_SelBetTicket] TO [bodbDownlineNetView]
GO

