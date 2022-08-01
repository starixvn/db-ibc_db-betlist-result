/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet, bodbDownlineNet, bodbDownlineNetView" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Acc_BetList_CashOut_History]
	@TransId			BIGINT,
	@CustId				INT,
	@WinlostDate		SMALLDATETIME,
	@BalanceUpDay		SMALLDATETIME
AS

/*
	Created: Razor@20220329
	Task: Get CashOut history ticket [#Redmine: 169007]
	DB: DBACC.bodb02
	Original:
	Revisions:
		- 20220329@Razor: Init [Redmine: #169007]
		- 20220808@Razor: Scale out DBTRANS [Redmine: #175253]
*/

BEGIN
	SET NOCOUNT ON

	IF (@WinlostDate >= @BalanceUpDay)
	BEGIN
		SELECT TransId,
				CashoutExtraInfo
		FROM dbo.CashOutSelling WITH (NOLOCK)
		WHERE transid = @TransId AND Custid = @Custid
	END
	ELSE
	BEGIN
		SELECT TransId,
				CashoutExtraInfo
		FROM bodb_Archive.dbo.CashOutSelling_bk WITH (NOLOCK)
		WHERE transid = @TransId AND Custid = @Custid
	END

END
GO