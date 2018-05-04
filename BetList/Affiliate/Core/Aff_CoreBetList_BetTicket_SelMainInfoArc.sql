/*<info serverAlias="DBARC-bodb_Archive" executers="bodbAdminNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/
USE bodb_archive
GO
ALTER PROCEDURE [dbo].[Aff_CoreBetList_BetTicket_SelMainInfoArc]
	@tempCust		TVP_TicketSportBettype READONLY,
	@ColumnOutput	VARCHAR(MAX) = NULL
AS

/*
	Created: Bobby.Nguyen
	Task: Core bet list for Affiliate
	DB: DBARC.bodb_Archive
	Original: DBARC.bodb_Archive.dbo.Age_CoreBetList_BetTicket_SelMainInfoArc

	Revisions:
		- 20170519@Kos: Clone from original SP and support CashOut [#Redmine: 71963]

	Param's Explanation:
	
	Dependences:
		- CREATE TABLE @tempCust (
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
	CREATE TABLE #MemBetTicket (
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

	-- CHECK for selecting from bettrans_bk
	IF (EXISTS (SELECT TOP 1 1 FROM @tempCust WHERE WhTicket = 3))
	BEGIN
		INSERT INTO #MemBetTicket
		EXEC [dbo].[Aff_CoreBetList_BetTicket_SelBettransArc] @tempCust = @tempCust
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
	/*IF (@ColumnOutput IS NULL)
	BEGIN
		SELECT *
		FROM #MemBetTicket t
		ORDER BY t.transid DESC
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
	*/

	SELECT *
	FROM #MemBetTicket
	ORDER BY transid DESC

	-- OUTPUT ticket in detail
	EXEC [dbo].[Aff_CoreBetList_BetTicket_SelDetailArc] @tempCust = @tempCust

	RETURN;
END



GO
GRANT EXECUTE ON [dbo].[Aff_CoreBetList_BetTicket_SelMainInfoArc] TO [bodbAdminNet] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[Aff_CoreBetList_BetTicket_SelMainInfoArc] TO [bodbDownlineNet] AS [dbo]
GO
