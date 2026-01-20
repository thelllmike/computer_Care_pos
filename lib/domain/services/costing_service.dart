/// Service for cost calculations, particularly Weighted Average Cost (WAC)
class CostingService {
  /// Calculates the new Weighted Average Cost after receiving new inventory
  ///
  /// Formula: New WAC = (Existing Value + New Purchase Value) / (Existing Qty + New Qty)
  ///
  /// [existingQuantity] - Current quantity on hand
  /// [existingTotalCost] - Total cost of existing inventory
  /// [newQuantity] - Quantity being received
  /// [newUnitCost] - Unit cost of new items
  ///
  /// Returns the new WAC rounded to 2 decimal places
  static double calculateWAC({
    required int existingQuantity,
    required double existingTotalCost,
    required int newQuantity,
    required double newUnitCost,
  }) {
    final totalQuantity = existingQuantity + newQuantity;
    if (totalQuantity == 0) return 0.0;

    final newTotalCost = existingTotalCost + (newQuantity * newUnitCost);
    final wac = newTotalCost / totalQuantity;

    // Round to 2 decimal places
    return (wac * 100).round() / 100;
  }

  /// Calculates the COGS (Cost of Goods Sold) for a sale item
  ///
  /// [quantity] - Quantity being sold
  /// [unitCost] - WAC at the time of sale
  static double calculateCOGS({
    required int quantity,
    required double unitCost,
  }) {
    return (quantity * unitCost * 100).round() / 100;
  }

  /// Calculates the gross profit for a sale item
  ///
  /// [revenue] - Total selling price
  /// [cogs] - Cost of goods sold
  static double calculateGrossProfit({
    required double revenue,
    required double cogs,
  }) {
    return (revenue - cogs * 100).round() / 100;
  }

  /// Calculates the profit margin as a percentage
  ///
  /// [revenue] - Total selling price
  /// [profit] - Gross profit
  static double calculateProfitMargin({
    required double revenue,
    required double profit,
  }) {
    if (revenue == 0) return 0.0;
    return ((profit / revenue) * 10000).round() / 100;
  }

  /// Calculates the markup percentage
  ///
  /// [sellingPrice] - Selling price per unit
  /// [cost] - Cost per unit (WAC)
  static double calculateMarkup({
    required double sellingPrice,
    required double cost,
  }) {
    if (cost == 0) return 0.0;
    return (((sellingPrice - cost) / cost) * 10000).round() / 100;
  }

  /// Updates inventory after receiving goods
  ///
  /// Returns a tuple of (new total cost, new WAC)
  static ({double newTotalCost, double newWAC}) updateInventoryOnGRN({
    required int existingQuantity,
    required double existingTotalCost,
    required int receivedQuantity,
    required double receivedUnitCost,
  }) {
    final newTotalCost = existingTotalCost + (receivedQuantity * receivedUnitCost);
    final newWAC = calculateWAC(
      existingQuantity: existingQuantity,
      existingTotalCost: existingTotalCost,
      newQuantity: receivedQuantity,
      newUnitCost: receivedUnitCost,
    );

    return (newTotalCost: newTotalCost, newWAC: newWAC);
  }

  /// Updates inventory after a sale
  ///
  /// Returns the new total cost remaining in inventory
  static double updateInventoryOnSale({
    required int existingQuantity,
    required double existingTotalCost,
    required int soldQuantity,
    required double wac,
  }) {
    final newQuantity = existingQuantity - soldQuantity;
    if (newQuantity <= 0) return 0.0;

    return existingTotalCost - (soldQuantity * wac);
  }
}
