/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet,bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Acc_Rpt_BetList_BetBuilder_Detail]
	@TransId	BIGINT,
	@CustId		INT
AS

/*
	Created: Kos@20190220
	Task : Get ticket detail from BetBuilder ticket (Single Match Parlay)
	DB: DBACC.bodb02
	Original:
	Revisions:
		- 20190219@Kos: Support BetBuilder [Redmine: #109822]
*/

BEGIN
	SET NOCOUNT ON

	SELECT
		s.SelectionType,
		s.Result
	FROM dbo.bettrans AS b WITH (NOLOCK)
		INNER JOIN dbo.SMP_MarketSelection AS s WITH (NOLOCK) ON s.MatchId = b.matchid AND s.MarketId = b.betcheck
	WHERE b.transid = @TransId
		AND b.custid = @CustId
		AND b.bettype = 38
END
GO



GRANT	EXECUTE	ON	Acc_Rpt_BetList_BetBuilder_Detail	TO	bodbAdminNet
GO
