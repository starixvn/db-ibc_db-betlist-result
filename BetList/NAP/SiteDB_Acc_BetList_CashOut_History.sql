/*<info serverAlias="DBSIG-bodb02" executers="bodbAdminNet, bodbDownlineNet, bodbDownlineNetView" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[SiteDB_Acc_BetList_CashOut_History]
	@TransId	BIGINT,
	@CustId		INT
AS

/*
	Created: 20220819@Kos
	Task: NAP/Alpha - Bet List - Ticket Detail of Cash Out history - SiteDB
	DB: DBSIG.bodb02

	Revisions:
		- 20220819@Kos: Scale out DBTRANS [Redmine: #175297]
*/

BEGIN
	SET NOCOUNT ON

	SELECT TransId,
		CashoutExtraInfo
	FROM dbo.CashOutSelling WITH (NOLOCK)
	WHERE TransID = @TransId AND Custid = @CustId
END
GO