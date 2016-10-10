ALTER PROCEDURE [dbo].[All_BetList_MatchResultGDSel]
	@TransId BIGINT
AS

/*
	Created: 20150505@Sophia
	Task: Get Gold Deluxe ticket result
	DB: DBAGE.bodb02; DBEXT.bodb02
	Revisions:
		- 20161010@Kos: Add product bet type range for sub tickets [Redmine: #65045]

	Param's Explanation: 
		@TransID: TransId of Bettrans table
*/

BEGIN
	SET NOCOUNT ON

	-- Get Sport Bettype Matrix (support Gold Deluxe only)
	DECLARE @SportBettype TABLE(ProductId TINYINT, Bettype SMALLINT, EventType TINYINT)

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype
	SELECT ProductID, BetType, EventType
	FROM dbo.f_SportBettypeMatrix_Sel (12, 0, 0, 2, '', '', @IsTest)

	IF EXISTS (SELECT TOP 1 1 FROM dbo.bettrans WITH (NOLOCK) WHERE transid = @TransId)
	BEGIN
		SELECT DISTINCT bg.TransDesc
		FROM dbo.bettransG AS bg WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON bg.bettype = sbt.Bettype
		WHERE bg.refno = @TransId
		END 
	ELSE IF EXISTS (SELECT TOP 1 1 FROM dbo.bettrans14 WITH (NOLOCK) WHERE transid = @TransId)
	BEGIN
		SELECT DISTINCT bg.TransDesc
		FROM dbo.bettransG14 AS bg WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON bg.bettype = sbt.Bettype
		WHERE bg.refno = @TransId
	END
	ELSE IF EXISTS (SELECT TOP 1 1 FROM DBARC.bodb_Archive.dbo.bettrans_bk WITH (NOLOCK) WHERE transid = @TransId)
	BEGIN
		SELECT DISTINCT bg.TransDesc
		FROM DBARC.bodb_Archive.dbo.BettransG AS bg WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON bg.bettype = sbt.Bettype
		WHERE bg.refno = @TransId
	END
END


GO 
GRANT EXECUTE ON [dbo].[All_BetList_MatchResultGDSel] TO [bodbDownlineNet]
GO 
GRANT EXECUTE ON [dbo].[All_BetList_MatchResultGDSel] TO [bodbExtAccNet]
GO 
GRANT EXECUTE ON [dbo].[All_BetList_MatchResultGDSel] TO [bodbDownlineNetView]
GO 
GRANT EXECUTE ON [dbo].[All_BetList_MatchResultGDSel] TO [bodbAdminNet]
GO 
GRANT EXECUTE ON [dbo].[All_BetList_MatchResultGDSel] TO [bodbLicenseeNet]
GO


 