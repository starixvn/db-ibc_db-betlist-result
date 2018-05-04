/*<info serverAlias="DBEXT-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/
USE bodb02
GO

ALTER PROCEDURE [dbo].[Aff_CoreBetList_BetTicket_SelMainInfo]
(
	@tempCust		[dbo].[TVP_TicketSportBettype]	READONLY,
	@TransStatus	[dbo].[TVP_BetTicketStatus]		READONLY,
	@ColumnOutput	VARCHAR(MAX)	= NULL
)
AS

/*
	Created: Bobby.Nguyen
	Task : Re-factor core bet list
	DB: DBEXT.bodb02
	Original: DBAGE.bodb02.dbo.Aff_CoreBetList_BetTicket_SelMainInfo

	Revisions:
		- 20160308@Bobby: Implement LIC core bet list for Affiliate site
		- 20170519@Kos: Support CashOut [#Redmine: 71963]

	Param's Explanation:
		- @tempCust AS TABLE
		(
			transid		BIGINT
			, refno		BIGINT
			, custid	INT
			, productId	INT
			, eventType	TINYINT
			, WhTicket	TINYINT
		)
*/

BEGIN
	SET NOCOUNT ON;
	
	-- CREATE output main info ticket
	CREATE TABLE #MemBetTicket
	(
		TransId				BIGINT
		, RefNo				BIGINT
		, CustId			INT
		, Username			NVARCHAR(30)
		, SportType			SMALLINT
		, BetType			SMALLINT
		, BetId				BIGINT
		, BetTeam			NVARCHAR(20)
		, Hdp1				SMALLMONEY
		, Hdp2				SMALLMONEY
		, OddsType			TINYINT
		, OddsId			INT
		, Odds				MONEY
		, MOdds				MONEY
		, Stake				MONEY
		, Actual_Stake		MONEY
		, Status			NVARCHAR(10)
		, TransDate			DATETIME
		, WinLostDate		DATETIME
		, WinLost			MONEY
		, AWinLost			MONEY
		, MWinLost			MONEY
		, SWinLost			MONEY
		, PlayerComm		MONEY
		, Comm				MONEY
		, AComm				MONEY
		, SComm				MONEY
		, APositionTaking	SMALLMONEY
		, MPositionTaking	SMALLMONEY
		, SPositionTaking	SMALLMONEY
		, TPositionTaking	SMALLMONEY
		, ASiscount			SMALLMONEY
		, MDiscount			SMALLMONEY
		, SDiscount			SMALLMONEY
		, LiveIndicator		BIT
		, LiveHomeScore		SMALLINT
		, LiveAwayScore		SMALLINT
		, FinalHomeScore	SMALLINT
		, FinalAwayScore	SMALLINT
		, HtHomeScore		SMALLINT
		, HtAwayScore		SMALLINT
		, Ip				NVARCHAR(15)
		, LeagueId			INT
		, MatchId			INT
		, MatchCode			NVARCHAR(50)
		, Race				NVARCHAR(20)
		, EventDate			DATETIME
		, HomeId			INT
		, AwayId			INT
		, BetStatus			NVARCHAR(50)
		, IsNeutral			BIT
		, Placing			NVARCHAR(20)
		, ShowTime			NVARCHAR(50)
		, BetCheck			NVARCHAR(50)
		, ComStatus			NVARCHAR(20)
		, TransDesc			NVARCHAR(1000)
		, OddsSpread		SMALLMONEY
		, BetdaqId			BIGINT
		, ExtraInfo			VARCHAR(1000)
		, OriginalBetType	SMALLINT
	);

	-- CHECK for selecting from translog
	IF EXISTS (SELECT TOP 1 1 FROM @tempCust WHERE WhTicket = 0)
	BEGIN
		INSERT INTO #MemBetTicket
		EXEC [dbo].[Aff_CoreBetList_BetTicket_SelTranslog] @tempCust = @tempCust, @TransStatus = @TransStatus
	END

	-- CHECK for selecting from bettrans
	IF EXISTS (SELECT TOP 1 1 FROM @tempCust WHERE WhTicket IN (1, 4))
	BEGIN
		INSERT INTO #MemBetTicket
		EXEC [dbo].[Aff_CoreBetList_BetTicket_SelBettrans] @tempCust = @tempCust, @TransStatus = @TransStatus
	END

	-- CHECK for selecting from bettrans14
	IF EXISTS (SELECT TOP 1 1 FROM @tempCust WHERE WhTicket = 2)
	BEGIN
		INSERT INTO #MemBetTicket
		EXEC [dbo].[Aff_CoreBetList_BetTicket_SelBettrans14] @tempCust = @tempCust, @TransStatus = @TransStatus
	END

	-- Get more info for CashOut tickets
	IF EXISTS (SELECT TOP 1 1 FROM #MemBetTicket WHERE BetType = 911)
	BEGIN
		UPDATE b
		SET b.Odds = ob.Odds,
			b.LiveIndicator = ob.LiveIndicator,
			b.LiveHomeScore = ob.LiveHomeScore,
			b.LiveAwayScore = ob.LiveAwayScore,
			b.OriginalBetType = ob.BetType,
			b.BetdaqId = ob.TransId
		FROM #MemBetTicket AS b
			INNER JOIN #MemBetTicket AS ob WITH (NOLOCK) ON b.RefNo = ob.TransId
		WHERE b.BetType = 911
	END

	-- OUTPUT main ticket
	IF @ColumnOutput IS NULL
	BEGIN
		SELECT *
		FROM #MemBetTicket
		ORDER BY transid DESC
	END
	ELSE
	BEGIN
		DECLARE @queryOutput NVARCHAR(MAX)
		SET @queryOutput = 'SELECT' 
							+ ' ' + @ColumnOutput 
							+ ' FROM #MemBetTicket t'
							+ '	ORDER BY t.transid DESC '
		
		EXEC sp_sqlexec @queryOutput
	END

	/*
	SELECT *
	FROM #MemBetTicket t
	ORDER BY t.transid DESC
	*/
	
	-- OUTPUT ticket in detail
	EXEC [dbo].[Aff_CoreBetList_BetTicket_SelDetail] @tempCust = @tempCust

	RETURN;
END

GO
