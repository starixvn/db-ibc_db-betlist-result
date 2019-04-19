/*<info serverAlias="DBACC-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_BetList_BetBuilder_Detail]
	@TransId	BIGINT,
	@CustId		INT
AS

/*
	Created: Kos@20191105
	Task : Get ticket detail from BetBuilder ticket (Single Match Parlay)
	DB: DBACC.bodb02
	Original:
	Revisions:
		- 20191105@Kos: Support Bet Builder [Redmine: #108298]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @MatchId	INT,
		@MarketId		VARCHAR(20),
		@TableId		TINYINT = 0

	SELECT
		@MatchId = matchid,
		@MarketId = betcheck,
		@TableId = 1			-- bettrans
	FROM dbo.bettrans WITH (NOLOCK)
	WHERE transid = @TransId
		AND custid = @CustId
		AND bettype = 38

	IF @TableId = 0
	BEGIN
		SELECT
			@MatchId = matchid,
			@MarketId = betcheck,
			@TableId = 2			-- bettrans14
		FROM dbo.bettrans14 WITH (NOLOCK)
		WHERE transid = @TransId
			AND custid = @CustId
			AND bettype = 38
	END

	IF @TableId = 0
	BEGIN
		SELECT
			@MatchId = matchid,
			@MarketId = betcheck,
			@TableId = 3			-- bettrans_bk
		FROM bodb_Archive.dbo.bettrans_bk WITH (NOLOCK)
		WHERE transid = @TransId
			AND custid = @CustId
			AND bettype = 38
	END

	IF @TableId = 1
	BEGIN
		SELECT
			SelectionType,
			Result
		FROM dbo.SMP_MarketSelection WITH (NOLOCK)
		WHERE MatchId = @MatchId AND MarketId = @MarketId
	END
	ELSE IF @TableId = 2
	BEGIN
		SELECT
			SelectionType,
			Result
		FROM dbo.SMP_MarketSelection14 WITH (NOLOCK)
		WHERE MatchId = @MatchId AND MarketId = @MarketId
	END
	ELSE IF @TableId = 3
	BEGIN
		SELECT
			SelectionType,
			Result
		FROM bodb_Archive.dbo.SMP_MarketSelection_bk WITH (NOLOCK)
		WHERE MatchId = @MatchId AND MarketId = @MarketId
	END
END
GO



GRANT EXECUTE ON [dbo].[Lrf_BetList_BetBuilder_Detail] TO [bodbLicenseeNet]
GO
